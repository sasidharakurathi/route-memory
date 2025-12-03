import 'dart:async'; 
import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;
import 'package:geolocator/geolocator.dart';
import 'package:flutter_compass/flutter_compass.dart'; 

import '../data/route_repository.dart';
import '../logic/tracking_provider.dart';
import '../logic/auth_provider.dart';
import '../logic/settings_provider.dart';
import 'saved_places_screen.dart';
import 'settings_screen.dart';
import 'constants.dart';

import 'explore_map_screen.dart';
import 'active_tracking_view.dart';
import 'navigation_screen.dart';
import 'widgets/user_location_marker.dart'; 

class _PinTipPainter extends CustomPainter {
  final Color color;
  _PinTipPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..style = PaintingStyle.fill;
    final path = ui.Path();
    path.moveTo(size.width / 2 - 8, 0);
    path.lineTo(size.width / 2 + 8, 0);
    path.lineTo(size.width / 2, size.height);
    path.close();
    canvas.drawPath(path, paint);
    final shadowPaint = Paint()..color = color.withOpacity(0.2)..style = PaintingStyle.fill;
    final shadowPath = ui.Path();
    shadowPath.moveTo(size.width / 2 - 8, 2);
    shadowPath.lineTo(size.width / 2 + 8, 2);
    shadowPath.lineTo(size.width / 2, size.height + 2);
    shadowPath.close();
    canvas.drawPath(shadowPath, shadowPaint);
  }
  @override
  bool shouldRepaint(_PinTipPainter oldDelegate) => oldDelegate.color != color;
}

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final Set<String> _selectedKeys = {};
  bool get _isSelectionMode => _selectedKeys.isNotEmpty;

  void _toggleSelection(String key) {
    setState(() {
      if (_selectedKeys.contains(key)) _selectedKeys.remove(key);
      else _selectedKeys.add(key);
    });
  }

  void _showRenameDialog(SavedRoute route) {
    final controller = TextEditingController(text: route.name);
    showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text("Rename Route"), scrollable: true, content: TextField(controller: controller, autofocus: true), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")), FilledButton(onPressed: () { if (controller.text.isNotEmpty) ref.read(repositoryProvider).updateRouteName(route.id, controller.text); Navigator.pop(ctx); }, child: const Text("Rename"))]));
  }
  void _confirmDeleteSingle(SavedRoute route) { showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text("Delete?"), content: Text("Delete '${route.name}'?"), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")), TextButton(style: TextButton.styleFrom(foregroundColor: kDangerColor), onPressed: () { ref.read(repositoryProvider).deleteRoute(route.id); Navigator.pop(ctx); }, child: const Text("Delete"))])); }
  void _confirmDeleteSelected(List<SavedRoute> routes) { showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text("Delete Selection"), content: Text("Delete ${_selectedKeys.length} routes?"), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")), FilledButton(style: FilledButton.styleFrom(backgroundColor: kDangerColor), onPressed: () { ref.read(repositoryProvider).deleteRoutes(_selectedKeys.toList()); setState(() => _selectedKeys.clear()); Navigator.pop(ctx); }, child: const Text("Delete All"))])); }
  void _confirmClearAll() { showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text("Clear All History"), content: const Text("Permanently delete everything?"), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")), FilledButton(style: FilledButton.styleFrom(backgroundColor: kDangerColor), onPressed: () { ref.read(repositoryProvider).clearAll(); Navigator.pop(ctx); }, child: const Text("Clear All"))])); }
  
  void _openSettings() { Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())); }
  void _openExploreMap() { Navigator.push(context, MaterialPageRoute(builder: (_) => const ExploreMapScreen())); }
  void _openSavedPlaces() { Navigator.push(context, MaterialPageRoute(builder: (_) => SavedPlacesScreen(onLocationSelected: (latlng, name) { Navigator.push(context, MaterialPageRoute(builder: (_) => NavigationScreen(target: latlng, targetName: name))); }))); }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    if (hours > 0) return "${hours}h ${minutes}m";
    return "${minutes}m";
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(settingsProvider);
    final routesAsync = ref.watch(savedRoutesProvider);
    final isTracking = ref.watch(trackingProvider).isTracking;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    if (isTracking) return const ActiveTrackingView();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      resizeToAvoidBottomInset: false,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            title: _isSelectionMode 
              ? Text("${_selectedKeys.length} Selected", style: const TextStyle(fontWeight: FontWeight.bold)) 
              : Text("Route Memory", style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.5, color: theme.textTheme.bodyMedium?.color)),
            backgroundColor: theme.scaffoldBackgroundColor,
            leading: _isSelectionMode ? IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => _selectedKeys.clear())) : null,
            actions: [
              if (_isSelectionMode)
                IconButton(icon: const Icon(Icons.delete_outline, color: kDangerColor), onPressed: () => routesAsync.whenData((d) => _confirmDeleteSelected(d)))
              else ...[
                IconButton(icon: Icon(Icons.delete_sweep_outlined, color: theme.iconTheme.color?.withOpacity(0.5)), tooltip: "Clear All", onPressed: _confirmClearAll),
                IconButton(icon: const Icon(Icons.account_circle, color: kPrimaryColor, size: 28), onPressed: _openSettings)
              ]
            ],
          ),
          
          routesAsync.when(
            loading: () => const SliverFillRemaining(child: Center(child: CircularProgressIndicator())),
            error: (err, stack) => SliverFillRemaining(child: Center(child: Text("Error: $err"))),
            data: (routes) {
              if (routes.isEmpty) {
                return SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.cloud_off, size: 64, color: isDark ? Colors.blueGrey[700] : Colors.blue[100]),
                        const SizedBox(height: 24),
                        Text("No routes yet", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: theme.textTheme.bodyMedium?.color)),
                        const SizedBox(height: 8),
                        Text("Start a new journey below!", style: TextStyle(color: theme.textTheme.bodySmall?.color)),
                      ],
                    ),
                  )
                );
              }
              
              final totalDist = routes.fold(0.0, (sum, r) => sum + r.totalDistance);
              final totalDuration = routes.fold(Duration.zero, (sum, r) => sum + r.duration);
              final distStr = ref.read(settingsProvider.notifier).getFormattedDistance(totalDist);

              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    Container(
                      margin: const EdgeInsets.only(bottom: 24),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isDark ? [const Color(0xFF1E3A8A), const Color(0xFF2563EB)] : [kPrimaryColor, const Color(0xFF60A5FA)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [BoxShadow(color: kPrimaryColor.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 6))]
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("LIFETIME STATS", style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildStatItem("Distance", distStr, Icons.show_chart, Colors.white),
                              _buildVerticalDivider(),
                              _buildStatItem("Time", _formatDuration(totalDuration), Icons.timer, Colors.white),
                              _buildVerticalDivider(),
                              _buildStatItem("Journeys", "${routes.length}", Icons.flag, Colors.white),
                            ],
                          )
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12, left: 4),
                      child: Text("RECENT HISTORY", style: TextStyle(color: theme.textTheme.bodySmall?.color, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1)),
                    ),
                    ...routes.map((route) {
                      final isSelected = _selectedKeys.contains(route.id);
                      return _buildRouteCard(route, isSelected, theme);
                    }).toList()
                  ]),
                )
              );
            }
          ),
        ]
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.cardColor,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))]
        ),
        child: SafeArea(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Expanded(child: _buildBottomBtn(icon: Icons.map_outlined, label: "Explore", onTap: _openExploreMap, isPrimary: false, theme: theme)),
              const SizedBox(width: 12),
              Expanded(flex: 2, child: _buildBottomBtn(icon: Icons.add_location_alt_outlined, label: "New Journey", onTap: () => ref.read(trackingProvider.notifier).startTracking(), isPrimary: true, theme: theme)),
              const SizedBox(width: 12),
              Expanded(child: _buildBottomBtn(icon: Icons.bookmark_outline, label: "Saved", onTap: _openSavedPlaces, isPrimary: false, theme: theme)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVerticalDivider() { return Container(width: 1, height: 40, color: Colors.white24); }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Icon(icon, color: Colors.white70, size: 14), const SizedBox(width: 4), Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold))]),
      const SizedBox(height: 4),
      Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w800)),
    ]);
  }

  Widget _buildBottomBtn({required IconData icon, required String label, required VoidCallback onTap, required bool isPrimary, required ThemeData theme}) {
    final isDark = theme.brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            color: isPrimary ? kPrimaryColor : (isDark ? Colors.white.withOpacity(0.05) : Colors.grey[100]),
            borderRadius: BorderRadius.circular(16),
            border: isPrimary ? null : Border.all(color: isDark ? Colors.white10 : Colors.grey[300]!),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: isPrimary ? Colors.white : theme.iconTheme.color, size: 24),
              const SizedBox(height: 2),
              Text(label, style: TextStyle(color: isPrimary ? Colors.white : theme.textTheme.bodyMedium?.color, fontSize: 10, fontWeight: FontWeight.bold))
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRouteCard(SavedRoute route, bool isSelected, ThemeData theme) {
    final distStr = ref.read(settingsProvider.notifier).getFormattedDistance(route.totalDistance);
    final isDark = theme.brightness == Brightness.dark;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isSelected ? (isDark ? kPrimaryColor.withOpacity(0.2) : Colors.blue[50]) : theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: isSelected ? Border.all(color: kPrimaryColor, width: 2) : null,
        boxShadow: kShadow
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onLongPress: () => _toggleSelection(route.id),
          onTap: () { if (_isSelectionMode) _toggleSelection(route.id); else Navigator.push(context, MaterialPageRoute(builder: (_) => RouteDetailScreen(route: route))); },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 50, height: 50,
                  decoration: BoxDecoration(color: isSelected ? kPrimaryColor : (isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFEFF6FF)), borderRadius: BorderRadius.circular(12)),
                  child: Icon(isSelected ? Icons.check : Icons.cloud_done_rounded, color: isSelected ? Colors.white : kPrimaryColor)
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(route.name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: theme.textTheme.bodyMedium?.color)),
                      const SizedBox(height: 4),
                      Text("${DateFormat.yMMMd().format(route.startTime)}  •  $distStr", style: TextStyle(fontSize: 13, color: theme.textTheme.bodySmall?.color, fontWeight: FontWeight.w500))
                    ]
                  )
                ),
                if (!_isSelectionMode) Row(mainAxisSize: MainAxisSize.min, children: [IconButton(icon: Icon(Icons.edit_outlined, size: 20, color: theme.iconTheme.color?.withOpacity(0.5)), onPressed: () => _showRenameDialog(route)), IconButton(icon: Icon(Icons.delete_outline, size: 20, color: theme.iconTheme.color?.withOpacity(0.5)), onPressed: () => _confirmDeleteSingle(route))])
              ]
            )
          )
        )
      )
    );
  }
}

class RouteDetailScreen extends ConsumerStatefulWidget {
  final SavedRoute route;
  const RouteDetailScreen({super.key, required this.route});
  @override
  ConsumerState<RouteDetailScreen> createState() => _RouteDetailScreenState();
}

class _RouteDetailScreenState extends ConsumerState<RouteDetailScreen> {
  final MapController _mapController = MapController(); 
  bool _isNavigating = false;
  LatLng? _targetPoint;
  String _targetName = "";
  List<LatLng> _navigationPath = [];
  StreamSubscription<Position>? _positionStream;
  StreamSubscription<CompassEvent>? _compassStream; 
  
  LatLng? _userLocation;
  double _currentHeading = 0.0;
  double _prevHeading = 0.0; 
  bool _isHeadsUpMode = false; 
  bool _shouldAutoCenter = true; 
  
  Duration _timeRemaining = Duration.zero;
  double _distanceRemaining = 0.0;
  LatLng? _lastFetchPos; 

  @override
  void initState() {
    super.initState();
    _startCompass();
  }

  @override
  void dispose() { 
    _positionStream?.cancel(); 
    _compassStream?.cancel();
    super.dispose(); 
  }

  void _startCompass() {
    try {
      _compassStream = FlutterCompass.events?.listen((event) {
        if (!mounted || event.heading == null) return;
        _updateHeadingSmoothly(event.heading!);
      });
    } catch (e) { debugPrint("Compass error: $e"); }
  }

  void _updateHeadingSmoothly(double newHeading) {
    newHeading = (newHeading + 360) % 360;
    double diff = newHeading - (_prevHeading % 360);
    if (diff < -180) diff += 360;
    if (diff > 180) diff -= 360;
    
    
    
    _prevHeading += diff; 
    
    if (_shouldAutoCenter && _userLocation != null && _isHeadsUpMode) {
      _mapController.moveAndRotate(_userLocation!, 18.0, -_prevHeading);
    }
  }

  Future<List<LatLng>> _fetchRoadRoute(LatLng start, LatLng end) async {
    try {
      final url = Uri.parse('http://router.project-osrm.org/route/v1/driving/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?overview=full&geometries=geojson');
      final request = await HttpClient().getUrl(url);
      final response = await request.close();
      if (response.statusCode == 200) {
        final jsonString = await response.transform(utf8.decoder).join();
        final data = jsonDecode(jsonString);
        if (data['routes'] != null && (data['routes'] as List).isNotEmpty) {
          final coordinates = data['routes'][0]['geometry']['coordinates'] as List;
          return coordinates.map((c) => LatLng(c[1], c[0])).toList();
        }
      }
    } catch (e) { debugPrint("Router Error: $e"); }
    return [start, end];
  }

  void _startNavigation(LatLng target, String name) async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) { permission = await Geolocator.requestPermission(); if (permission == LocationPermission.denied) return; }
    setState(() { _isNavigating = true; _targetPoint = target; _targetName = name; _lastFetchPos = null; _shouldAutoCenter = true; });
    
    LocationSettings locationSettings;
    if (defaultTargetPlatform == TargetPlatform.android) { locationSettings = AndroidSettings(accuracy: LocationAccuracy.bestForNavigation, distanceFilter: 0, forceLocationManager: true, intervalDuration: const Duration(milliseconds: 500)); } else { locationSettings = const LocationSettings(accuracy: LocationAccuracy.bestForNavigation, distanceFilter: 0); }

    _positionStream?.cancel();
    _positionStream = Geolocator.getPositionStream(locationSettings: locationSettings).listen((Position position) {
      final userPos = LatLng(position.latitude, position.longitude);
      
      setState(() => _userLocation = userPos);
      if (_shouldAutoCenter) {
        if (_isHeadsUpMode) {
          _mapController.moveAndRotate(userPos, 18.0, -_prevHeading);
        } else {
          _mapController.move(userPos, 18.0);
        }
      }
      _recalculatePathToTarget(userPos);
    });
    if (_userLocation != null) _recalculatePathToTarget(_userLocation!);
  }

  void _stopNavigation() { _positionStream?.cancel(); setState(() { _isNavigating = false; _navigationPath = []; _userLocation = null; _distanceRemaining = 0; }); }

  void _toggleHeadsUpMode() {
    setState(() => _isHeadsUpMode = !_isHeadsUpMode);
    if (_userLocation != null) {
      if (_isHeadsUpMode) {
        _mapController.rotate(-_prevHeading);
      } else {
        _mapController.rotate(0.0);
      }
    } else {
      _mapController.rotate(_isHeadsUpMode ? -_prevHeading : 0.0);
    }
  }

  void _recenterMap() {
    setState(() => _shouldAutoCenter = true);
    if (_userLocation != null) {
      if (_isHeadsUpMode) _mapController.moveAndRotate(_userLocation!, 18.0, -_prevHeading);
      else _mapController.move(_userLocation!, 18.0);
    }
  }

  String _formatTimeRemaining() {
    if (_timeRemaining.inSeconds < 60) return "${_timeRemaining.inSeconds}s";
    final mins = _timeRemaining.inMinutes;
    final secs = _timeRemaining.inSeconds % 60;
    if (secs == 0) return "${mins}m";
    return "${mins}m ${secs}s";
  }

  void _recalculatePathToTarget(LatLng userPos) async {
    if (_targetPoint == null) return;
    int userIndex = _findNearestIndex(userPos);
    final nearestRoutePoint = widget.route.points[userIndex];
    final distToRoute = const Distance().as(LengthUnit.Meter, userPos, LatLng(nearestRoutePoint.latitude, nearestRoutePoint.longitude));

    if (distToRoute > 40) {
       if (_lastFetchPos == null || const Distance().as(LengthUnit.Meter, _lastFetchPos!, userPos) > 20) {
          final directRoadPath = await _fetchRoadRoute(userPos, _targetPoint!);
          setState(() { _navigationPath = directRoadPath; _distanceRemaining = _calculatePathDistance(directRoadPath); _timeRemaining = Duration(seconds: (_distanceRemaining / 1.4).round()); });
          _lastFetchPos = userPos;
       }
       return; 
    }
    _lastFetchPos = null; 
    int targetIndex = _findNearestIndex(_targetPoint!);
    List<RoutePoint> rawSegment = [];
    if (userIndex < targetIndex) { rawSegment = widget.route.points.sublist(userIndex, targetIndex + 1); } else { final segment = widget.route.points.sublist(targetIndex, userIndex + 1); rawSegment = segment.reversed.toList(); }
    final routeSlice = rawSegment.map((p) => LatLng(p.latitude, p.longitude)).toList();
    final fullPath = [userPos, ...routeSlice];
    double totalDist = _calculatePathDistance(fullPath);
    setState(() { _navigationPath = fullPath; _distanceRemaining = totalDist; _timeRemaining = Duration(seconds: (totalDist / 1.4).round()); });
  }

  double _calculatePathDistance(List<LatLng> path) { double totalDist = 0; const distance = Distance(); for(int i = 0; i < path.length - 1; i++) { totalDist += distance.as(LengthUnit.Meter, path[i], path[i+1]); } return totalDist; }
  int _findNearestIndex(LatLng pos) { int closestIndex = 0; double minDistance = double.infinity; const distance = Distance(); for (int i = 0; i < widget.route.points.length; i++) { final rp = widget.route.points[i]; final d = distance.as(LengthUnit.Meter, pos, LatLng(rp.latitude, rp.longitude)); if (d < minDistance) { minDistance = d; closestIndex = i; } } return closestIndex; }

  @override
  Widget build(BuildContext context) {
    final mapSettings = ref.watch(settingsProvider);
    final centerLat = widget.route.points.map((e) => e.latitude).reduce((a, b) => a + b) / widget.route.points.length;
    final centerLng = widget.route.points.map((e) => e.longitude).reduce((a, b) => a + b) / widget.route.points.length;
    final path = widget.route.points.map((p) => LatLng(p.latitude, p.longitude)).toList();
    final distStr = ref.read(settingsProvider.notifier).getFormattedDistance(widget.route.totalDistance);
    
    
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final interactionFlags = _isHeadsUpMode 
        ? mapSettings.interactionFlags & ~InteractiveFlag.rotate 
        : mapSettings.interactionFlags;

    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: LatLng(centerLat, centerLng), 
              initialZoom: 15.0,
              interactionOptions: InteractionOptions(flags: interactionFlags),
              onPositionChanged: (pos, hasGesture) {
                if (hasGesture) setState(() => _shouldAutoCenter = false);
              },
            ),
            children: [
              
              if (isDark)
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.sasidharakurathi.routememory',
                  retinaMode: mapSettings.retinaMode,
                  panBuffer: mapSettings.panBuffer,
                  tileBuilder: (context, widget, tile) {
                    return ColorFiltered(
                      colorFilter: const ColorFilter.matrix([
                        -1,  0,  0, 0, 255, 
                         0, -1,  0, 0, 255, 
                         0,  0, -1, 0, 255, 
                         0,  0,  0, 1,   0, 
                      ]),
                      child: widget,
                    );
                  },
                )
              else
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.sasidharakurathi.routememory',
                  retinaMode: mapSettings.retinaMode,
                  panBuffer: mapSettings.panBuffer,
                ),
              PolylineLayer(
                polylines: [
                  Polyline(points: path, strokeWidth: 6.0, color: _isNavigating ? kPrimaryColor.withOpacity(0.5) : kPrimaryColor),
                  if (_isNavigating && _navigationPath.isNotEmpty)
                    Polyline(
                      points: _navigationPath, 
                      strokeWidth: 6.0, 
                      color: kAccentColor, 
                      strokeJoin: StrokeJoin.round, 
                    ),
                ],
              ),
              
              MarkerLayer(markers: [
                _buildMarker(path.first, Icons.flag_rounded, kAccentColor, "START"),
                _buildMarker(path.last, Icons.flag_rounded, kDangerColor, "END"),
                for (var cp in widget.route.checkpoints) _buildMarker(LatLng(cp.latitude, cp.longitude), Icons.star_rounded, Colors.amber, cp.name),
                if (_userLocation != null)
                  Marker(
                    point: _userLocation!, width: 60, height: 60,
                    alignment: Alignment.center,
                    
                    child: const RepaintBoundary(child: UserLocationMarker()),
                  ),
              ]),
            ],
          ),

          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16,
            child: _buildBlurButton(
              icon: Icons.arrow_back, 
              onTap: () => Navigator.pop(context),
              theme: theme
            )
          ),

          if (_isNavigating)
            Positioned(
              top: MediaQuery.of(context).padding.top + 16, 
              right: 16, 
              child: Column(
                children: [
                  _buildBlurButton(
                    icon: _isHeadsUpMode ? Icons.explore : Icons.explore_off, 
                    color: _isHeadsUpMode ? kPrimaryColor : (isDark ? Colors.white : Colors.black87), 
                    onTap: _toggleHeadsUpMode,
                    theme: theme
                  ), 
                  const SizedBox(height: 12), 
                  _buildBlurButton(
                    icon: Icons.my_location, 
                    color: _shouldAutoCenter ? kPrimaryColor : (isDark ? Colors.white54 : Colors.grey), 
                    onTap: _recenterMap,
                    theme: theme
                  )
                ]
              )
            ),

          if (_isNavigating)
            _buildNavPanel(theme)
          else
            _buildInfoPanel(context, distStr, theme)
        ],
      ),
    );
  }

  Widget _buildBlurButton({required IconData icon, Color? color, required VoidCallback onTap, required ThemeData theme}) {
    return GestureDetector(onTap: onTap, child: Container(margin: const EdgeInsets.all(8), width: 44, height: 44, decoration: BoxDecoration(color: theme.cardColor, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8)]), child: Icon(icon, color: color ?? theme.iconTheme.color, size: 24)));
  }

  Marker _buildMarker(LatLng pos, IconData icon, Color color, String label) {
    return Marker(
      point: pos,
      width: 100, height: 100,
      alignment: const Alignment(0.0, 0.0),
      child: GestureDetector(
        onTap: () => _showNavDialog(pos, label),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 40, decoration: BoxDecoration(color: color, borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20), bottomLeft: Radius.circular(12), bottomRight: Radius.circular(12)), boxShadow: [BoxShadow(color: color.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 4))], border: Border.all(color: Colors.white, width: 2)), child: Icon(icon, color: Colors.white, size: 22)),
            CustomPaint(size: const Size(40, 10), painter: _PinTipPainter(color: color)),
            if (label.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: color, width: 0.5), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))]), child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold, overflow: TextOverflow.ellipsis), maxLines: 1))),
          ],
        ),
      ),
    );
  }

  Widget _buildNavPanel(ThemeData theme) {
    final remainingStr = ref.read(settingsProvider.notifier).getFormattedDistance(_distanceRemaining);
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final isDark = theme.brightness == Brightness.dark;

    return Positioned(
      bottom: 30 + bottomPadding, left: 16, right: 16,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: theme.cardColor, borderRadius: kCardRadius, boxShadow: kShadow),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, 
                children: [
                  Text("Navigating to $_targetName", style: TextStyle(color: isDark ? Colors.white54 : Colors.grey[500], fontSize: 12, fontWeight: FontWeight.w600)), 
                  const SizedBox(height: 4), 
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline, 
                    textBaseline: TextBaseline.alphabetic, 
                    children: [
                      Text(_formatTimeRemaining(), style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: kPrimaryColor)), 
                      const SizedBox(width: 12), 
                      Text(remainingStr, style: TextStyle(fontSize: 16, color: isDark ? Colors.white70 : Colors.black54, fontWeight: FontWeight.w500))
                    ]
                  )
                ]
              )
            ),
            GestureDetector(
              onTap: _stopNavigation, 
              child: Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: kDangerColor.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.close, size: 28, color: kDangerColor))
            )
          ],
        ),
      ),
    );
  }

  Widget _buildInfoPanel(BuildContext context, String distStr, ThemeData theme) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final isDark = theme.brightness == Brightness.dark;
    
    return Positioned(
      bottom: 30 + bottomPadding, left: 16, right: 16,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: theme.cardColor, borderRadius: kCardRadius, boxShadow: kShadow),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.route.name, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: theme.textTheme.bodyMedium?.color)),
            const SizedBox(height: 20),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              _buildInfoItem(Icons.access_time_rounded, "Time", DateFormat('h:mm a').format(widget.route.startTime), theme), 
              _buildInfoItem(Icons.straighten_rounded, "Dist", distStr, theme), 
              _buildInfoItem(Icons.flag_rounded, "Stops", "${widget.route.checkpoints.length}", theme)
            ]),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity, 
              height: 56, 
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: isDark ? kPrimaryColor : Colors.black87,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
                ), 
                icon: const Icon(Icons.navigation_rounded), 
                label: const Text("Start Guidance", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)), 
                onPressed: () { final start = widget.route.points.first; _showNavDialog(LatLng(start.latitude, start.longitude), "Start Point"); }
              )
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String label, String value, ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    return Column(children: [Icon(icon, color: isDark ? Colors.grey[500] : Colors.grey[400], size: 24), const SizedBox(height: 8), Text(value, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: theme.textTheme.bodyMedium?.color)), Text(label, style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[500], fontSize: 12, fontWeight: FontWeight.w600))]);
  }

  void _showNavDialog(LatLng target, String name) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    showModalBottomSheet(context: context, backgroundColor: theme.cardColor, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))), builder: (ctx) => SafeArea(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))), const SizedBox(height: 24), Text("Navigate to $name?", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: theme.textTheme.bodyMedium?.color)), const SizedBox(height: 8), Text("This will guide you along the recorded path back to $name.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600], fontSize: 16)), const SizedBox(height: 32), Row(children: [Expanded(child: OutlinedButton(style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), onPressed: () => Navigator.pop(ctx), child: const Text("Cancel"))), const SizedBox(width: 16), Expanded(child: FilledButton(style: FilledButton.styleFrom(backgroundColor: isDark ? kPrimaryColor : Colors.black87, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), onPressed: () { Navigator.pop(ctx); _startNavigation(target, name); }, child: const Text("Let's Go")))])]))));
  }
}
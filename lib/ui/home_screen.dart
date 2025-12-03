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

import '../data/route_repository.dart';
import '../logic/tracking_provider.dart';
import '../logic/auth_provider.dart';
import 'saved_places_screen.dart';
import 'constants.dart';

// Imports for the extracted screens
import 'explore_map_screen.dart';
import 'active_tracking_view.dart';
import 'navigation_screen.dart';

// Custom painter for pin marker tip
class _PinTipPainter extends CustomPainter {
  final Color color;
  _PinTipPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = ui.Path();
    path.moveTo(size.width / 2 - 8, 0); // Left top
    path.lineTo(size.width / 2 + 8, 0); // Right top
    path.lineTo(size.width / 2, size.height); // Bottom point
    path.close();

    canvas.drawPath(path, paint);

    // Shadow
    final shadowPaint = Paint()
      ..color = color.withOpacity(0.2)
      ..style = PaintingStyle.fill;
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

// -----------------------------------------------------------------------------
// 1. HOME SCREEN
// -----------------------------------------------------------------------------

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
  void _showAboutDialog() { showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text("Route Memory"), content: const Text("Version 2.8\nGlobal Marker Fix."), actions: [TextButton(onPressed: () { Navigator.pop(ctx); ref.read(authRepositoryProvider).signOut(); }, style: TextButton.styleFrom(foregroundColor: Colors.red), child: const Text("Log Out")), FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text("Close"))])); }
  
  void _openExploreMap() { Navigator.push(context, MaterialPageRoute(builder: (_) => const ExploreMapScreen())); }
  void _openSavedPlaces() { Navigator.push(context, MaterialPageRoute(builder: (_) => SavedPlacesScreen(onLocationSelected: (latlng, name) { Navigator.push(context, MaterialPageRoute(builder: (_) => NavigationScreen(target: latlng, targetName: name))); }))); }

  @override
  Widget build(BuildContext context) {
    final routesAsync = ref.watch(savedRoutesProvider);
    final isTracking = ref.watch(trackingProvider).isTracking;
    if (isTracking) return const ActiveTrackingView();

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      resizeToAvoidBottomInset: false,
      body: CustomScrollView(slivers: [SliverAppBar(title: _isSelectionMode ? Text("${_selectedKeys.length} Selected", style: const TextStyle(fontWeight: FontWeight.bold)) : Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("Route Memory", style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.5)), Row(children: [IconButton(icon: const Icon(Icons.bookmark_outline, color: kPrimaryColor), tooltip: "Saved Places", onPressed: _openSavedPlaces), IconButton(icon: const Icon(Icons.delete_sweep_outlined, color: Colors.grey), onPressed: _confirmClearAll), IconButton(icon: const Icon(Icons.account_circle_outlined, color: kPrimaryColor), onPressed: _showAboutDialog)])]), backgroundColor: kSurfaceColor, leading: _isSelectionMode ? IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => _selectedKeys.clear())) : null, actions: [if (_isSelectionMode) IconButton(icon: const Icon(Icons.delete_outline, color: kDangerColor), onPressed: () => routesAsync.whenData((d) => _confirmDeleteSelected(d))), const SizedBox(width: 8)]), routesAsync.when(loading: () => const SliverFillRemaining(child: Center(child: CircularProgressIndicator())), error: (err, stack) => SliverFillRemaining(child: Center(child: Text("Error: $err"))), data: (routes) { if (routes.isEmpty) return SliverFillRemaining(child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.cloud_off, size: 64, color: Colors.blue[100]), const SizedBox(height: 24), Text("No routes yet", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[800]))]))); return SliverPadding(padding: const EdgeInsets.all(16), sliver: SliverList(delegate: SliverChildBuilderDelegate((context, index) { final route = routes[index]; final isSelected = _selectedKeys.contains(route.id); return _buildRouteCard(route, isSelected); }, childCount: routes.length))); }), const SliverToBoxAdapter(child: SizedBox(height: 120))]),
      floatingActionButton: _isSelectionMode ? null : Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [FloatingActionButton.extended(heroTag: "explore", onPressed: _openExploreMap, label: const Text("Explore Map"), icon: const Icon(Icons.map), backgroundColor: Colors.white, foregroundColor: kPrimaryColor, elevation: 4), const SizedBox(height: 16), FloatingActionButton.extended(heroTag: "start", onPressed: () => ref.read(trackingProvider.notifier).startTracking(), label: const Text("New Journey"), icon: const Icon(Icons.add_location_alt_outlined), backgroundColor: kPrimaryColor, foregroundColor: Colors.white, elevation: 4)]),
    );
  }

  Widget _buildRouteCard(SavedRoute route, bool isSelected) {
    final distStr = route.totalDistance > 1000 ? "${(route.totalDistance/1000).toStringAsFixed(2)} km" : "${route.totalDistance.toStringAsFixed(0)} m";
    return Container(margin: const EdgeInsets.only(bottom: 12), decoration: BoxDecoration(color: isSelected ? Colors.blue[50] : Colors.white, borderRadius: BorderRadius.circular(16), border: isSelected ? Border.all(color: kPrimaryColor, width: 2) : null, boxShadow: kShadow), child: Material(color: Colors.transparent, child: InkWell(borderRadius: BorderRadius.circular(16), onLongPress: () => _toggleSelection(route.id), onTap: () { if (_isSelectionMode) _toggleSelection(route.id); else Navigator.push(context, MaterialPageRoute(builder: (_) => RouteDetailScreen(route: route))); }, child: Padding(padding: const EdgeInsets.all(16), child: Row(children: [Container(width: 50, height: 50, decoration: BoxDecoration(color: isSelected ? kPrimaryColor : const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(12)), child: Icon(isSelected ? Icons.check : Icons.cloud_done_rounded, color: isSelected ? Colors.white : kPrimaryColor)), const SizedBox(width: 16), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(route.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), const SizedBox(height: 4), Text("${DateFormat.yMMMd().format(route.startTime)}  •  $distStr", style: TextStyle(fontSize: 13, color: Colors.grey[600], fontWeight: FontWeight.w500))])), if (!_isSelectionMode) Row(mainAxisSize: MainAxisSize.min, children: [IconButton(icon: const Icon(Icons.edit_outlined, size: 20, color: Colors.grey), onPressed: () => _showRenameDialog(route)), IconButton(icon: const Icon(Icons.delete_outline, size: 20, color: Colors.grey), onPressed: () => _confirmDeleteSingle(route))])])))));
  }
}

// -----------------------------------------------------------------------------
// 3. DETAIL SCREEN (Navigation Mode)
// -----------------------------------------------------------------------------

class RouteDetailScreen extends ConsumerStatefulWidget {
  final SavedRoute route;
  const RouteDetailScreen({super.key, required this.route});
  @override
  ConsumerState<RouteDetailScreen> createState() => _RouteDetailScreenState();
}

class _RouteDetailScreenState extends ConsumerState<RouteDetailScreen> {
  bool _isNavigating = false;
  LatLng? _targetPoint;
  String _targetName = "";
  List<LatLng> _navigationPath = [];
  StreamSubscription<Position>? _positionStream;
  LatLng? _userLocation;
  double _currentHeading = 0.0;
  Duration _timeRemaining = Duration.zero;
  double _distanceRemaining = 0.0;
  LatLng? _lastFetchPos; 
  List<LatLng> _cachedRoadPath = []; 

  @override
  void dispose() { _positionStream?.cancel(); super.dispose(); }

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

  List<Marker> _getDirectionArrows() {
    List<Marker> arrows = [];
    if (widget.route.points.length < 2) return [];
    double accumulatedDistance = 0;
    const distance = Distance();
    for (int i = 0; i < widget.route.points.length - 1; i++) {
      final p1 = widget.route.points[i];
      final p2 = widget.route.points[i + 1];
      final d = distance.as(LengthUnit.Meter, LatLng(p1.latitude, p1.longitude), LatLng(p2.latitude, p2.longitude));
      accumulatedDistance += d;
      if (accumulatedDistance > 40) {
        accumulatedDistance = 0;
        double bearing = Geolocator.bearingBetween(p1.latitude, p1.longitude, p2.latitude, p2.longitude);
        arrows.add(Marker(point: LatLng(p1.latitude, p1.longitude), width: 20, height: 20, child: Transform.rotate(angle: (bearing * (math.pi / 180)), child: const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 20))));
      }
    }
    return arrows;
  }

  void _startNavigation(LatLng target, String name) async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) { permission = await Geolocator.requestPermission(); if (permission == LocationPermission.denied) return; }
    setState(() { _isNavigating = true; _targetPoint = target; _targetName = name; _lastFetchPos = null; _cachedRoadPath = []; });
    
    LocationSettings locationSettings;
    if (defaultTargetPlatform == TargetPlatform.android) { locationSettings = AndroidSettings(accuracy: LocationAccuracy.bestForNavigation, distanceFilter: 0, forceLocationManager: true, intervalDuration: const Duration(seconds: 1)); } else if (defaultTargetPlatform == TargetPlatform.iOS) { locationSettings = AppleSettings(accuracy: LocationAccuracy.bestForNavigation, activityType: ActivityType.fitness, distanceFilter: 0, pauseLocationUpdatesAutomatically: false, showBackgroundLocationIndicator: true); } else { locationSettings = const LocationSettings(accuracy: LocationAccuracy.bestForNavigation, distanceFilter: 0); }

    _positionStream?.cancel();
    _positionStream = Geolocator.getPositionStream(locationSettings: locationSettings).listen((Position position) {
      final userPos = LatLng(position.latitude, position.longitude);
      double newHeading = position.heading;
      if (newHeading == 0.0 && _userLocation != null) {
         final dist = const Distance().as(LengthUnit.Meter, _userLocation!, userPos);
         if (dist > 0.5) { newHeading = Geolocator.bearingBetween(_userLocation!.latitude, _userLocation!.longitude, userPos.latitude, userPos.longitude); } else { newHeading = _currentHeading; }
      }
      setState(() { _userLocation = userPos; _currentHeading = newHeading; });
      _recalculatePathToTarget(userPos);
    });
    if (_userLocation != null) _recalculatePathToTarget(_userLocation!);
  }

  void _stopNavigation() { _positionStream?.cancel(); setState(() { _isNavigating = false; _navigationPath = []; _cachedRoadPath = []; _userLocation = null; _distanceRemaining = 0; }); }

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
    final centerLat = widget.route.points.map((e) => e.latitude).reduce((a, b) => a + b) / widget.route.points.length;
    final centerLng = widget.route.points.map((e) => e.longitude).reduce((a, b) => a + b) / widget.route.points.length;
    final path = widget.route.points.map((p) => LatLng(p.latitude, p.longitude)).toList();

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        leading: _buildBlurButton(icon: Icons.arrow_back, onTap: () => Navigator.pop(context)),
        actions: [
          if (_isNavigating)
             Padding(padding: const EdgeInsets.only(right: 16), child: _buildBlurButton(icon: Icons.close, color: kDangerColor, onTap: _stopNavigation)),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(initialCenter: LatLng(centerLat, centerLng), initialZoom: 15.0),
            children: [
              // CHANGED: OSM Standard Tiles
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.route_memory',
                retinaMode: true,
                maxNativeZoom: 19, // FIX ADDED
              ),
              PolylineLayer(
                polylines: [
                  Polyline(points: path, strokeWidth: 6.0, color: _isNavigating ? kPrimaryColor.withOpacity(0.5) : kPrimaryColor),
                  if (_isNavigating && _navigationPath.isNotEmpty)
                    Polyline(points: _navigationPath, strokeWidth: 6.0, color: kAccentColor, isDotted: true),
                ],
              ),
              if (!_isNavigating) MarkerLayer(markers: _getDirectionArrows()),
              MarkerLayer(markers: [
                _buildMarker(path.first, Icons.flag_rounded, kAccentColor, "START"),
                _buildMarker(path.last, Icons.flag_rounded, kDangerColor, "END"),
                for (var cp in widget.route.checkpoints) _buildMarker(LatLng(cp.latitude, cp.longitude), Icons.star_rounded, Colors.amber, cp.name),
                if (_userLocation != null) 
                  Marker(
                    point: _userLocation!, width: 60, height: 60, 
                    alignment: Alignment.center, // Arrows center properly
                    child: Transform.rotate(angle: (_currentHeading * (math.pi / 180)), child: Container(decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)]), child: Icon(Icons.arrow_upward_rounded, color: kPrimaryColor, size: 30))),
                  ),
              ]),
            ],
          ),

          if (_isNavigating)
            _buildNavPanel()
          else
            _buildInfoPanel(context)
        ],
      ),
    );
  }

  Widget _buildBlurButton({required IconData icon, Color color = Colors.black87, required VoidCallback onTap}) {
    return GestureDetector(onTap: onTap, child: Container(margin: const EdgeInsets.all(8), width: 44, height: 44, decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8)]), child: Icon(icon, color: color, size: 24)));
  }

  Marker _buildMarker(LatLng pos, IconData icon, Color color, String label) {
    // Pin-style marker with tip pointing to exact coordinate.
    return Marker(
      point: pos,
      width: 100,
      height: 100,
      alignment: const Alignment(0.0, 0.0),
      child: GestureDetector(
        onTap: () => _showNavDialog(pos, label),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Pin head (rounded top)
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
                boxShadow: [
                  BoxShadow(color: color.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 4)),
                ],
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            // Pin tip (triangle pointing down)
            CustomPaint(
              size: const Size(40, 10),
              painter: _PinTipPainter(color: color),
            ),
            // Marker name label
            if (label.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: color, width: 0.5),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2)),
                    ],
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      color: color,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      overflow: TextOverflow.ellipsis,
                    ),
                    maxLines: 1,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavPanel() {
    return Positioned(
      bottom: 30, left: 16, right: 16,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Colors.white, borderRadius: kCardRadius, boxShadow: kShadow),
        child: Row(
          children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text("Navigating to $_targetName", style: TextStyle(color: Colors.grey[500], fontSize: 12, fontWeight: FontWeight.w600)), const SizedBox(height: 4), Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [Text(_timeRemaining.inMinutes.toString(), style: const TextStyle(fontSize: 42, fontWeight: FontWeight.w800, color: Colors.black)), const Text(" min", style: TextStyle(fontSize: 18, color: Colors.grey, fontWeight: FontWeight.w600))]), Text("${(_distanceRemaining/1000).toStringAsFixed(2)} km remaining", style: const TextStyle(fontSize: 16, color: Colors.black54, fontWeight: FontWeight.w500))])),
            Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: kAccentColor.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.directions_walk_rounded, size: 32, color: kAccentColor))
          ],
        ),
      ),
    );
  }

  Widget _buildInfoPanel(BuildContext context) {
    return Positioned(
      bottom: 30, left: 16, right: 16,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: Colors.white, borderRadius: kCardRadius, boxShadow: kShadow),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.route.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
            const SizedBox(height: 20),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [_buildInfoItem(Icons.access_time_rounded, "Time", DateFormat('h:mm a').format(widget.route.startTime)), _buildInfoItem(Icons.straighten_rounded, "Dist", "${(widget.route.totalDistance/1000).toStringAsFixed(2)} km"), _buildInfoItem(Icons.flag_rounded, "Stops", "${widget.route.checkpoints.length}")]),
            const SizedBox(height: 24),
            SizedBox(width: double.infinity, height: 56, child: FilledButton.icon(style: FilledButton.styleFrom(backgroundColor: kPrimaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))), icon: const Icon(Icons.navigation_rounded), label: const Text("Start Guidance", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)), onPressed: () { final start = widget.route.points.first; _showNavDialog(LatLng(start.latitude, start.longitude), "Start Point"); })),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String label, String value) {
    return Column(children: [Icon(icon, color: Colors.grey[400], size: 24), const SizedBox(height: 8), Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)), Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 12, fontWeight: FontWeight.w600))]);
  }

  void _showNavDialog(LatLng target, String name) {
    showModalBottomSheet(context: context, backgroundColor: Colors.white, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))), builder: (ctx) => SafeArea(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))), const SizedBox(height: 24), Text("Navigate to $name?", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)), const SizedBox(height: 8), Text("This will guide you along the recorded path back to $name.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600], fontSize: 16)), const SizedBox(height: 32), Row(children: [Expanded(child: OutlinedButton(style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), onPressed: () => Navigator.pop(ctx), child: const Text("Cancel"))), const SizedBox(width: 16), Expanded(child: FilledButton(style: FilledButton.styleFrom(backgroundColor: kPrimaryColor, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), onPressed: () { Navigator.pop(ctx); _startNavigation(target, name); }, child: const Text("Let's Go")))])]))));
  }
}
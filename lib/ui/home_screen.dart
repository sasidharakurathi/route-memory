import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;
import 'package:geolocator/geolocator.dart';
import 'dart:convert';
import 'dart:io';

import '../data/route_repository.dart';
import '../logic/tracking_provider.dart';

const kPrimaryColor = Color(0xFF2563EB); 
const kAccentColor = Color(0xFF10B981);  
const kDangerColor = Color(0xFFEF4444);  
const kSurfaceColor = Colors.white;
final kShadow = [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, 4))];
final kCardRadius = BorderRadius.circular(24);

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final Set<dynamic> _selectedKeys = {}; 
  bool get _isSelectionMode => _selectedKeys.isNotEmpty;

  void _toggleSelection(dynamic key) {
    setState(() {
      if (_selectedKeys.contains(key)) {
        _selectedKeys.remove(key);
      } else {
        _selectedKeys.add(key);
      }
    });
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: kPrimaryColor.withOpacity(0.1), shape: BoxShape.circle),
              child: const Icon(Icons.map_rounded, color: kPrimaryColor),
            ),
            const SizedBox(width: 12),
            const Text("Route Memory"),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Version 0.0.1.1", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 16),
            const Text("A GPS tracking tool to record, manage, and retrace your journeys."),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            const Text("CREDITS", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 4),
            const Text("• Developed with Flutter & Dart"),
            const Text("• Maps by OpenStreetMap"),
            const Text("• Routing by OSRM"),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            const Text("DEVELOPED BY", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
            const Text("Sasidhar Akurathi"),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  void _showRenameDialog(SavedRoute route) {
    final controller = TextEditingController(text: route.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Rename Route"),
        scrollable: true, 
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: "Enter new name",
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: Colors.grey[50],
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          FilledButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                ref.read(savedRoutesProvider.notifier).renameRoute(route, controller.text);
              }
              Navigator.pop(ctx);
            }, 
            child: const Text("Rename")
          ),
        ],
      ),
    );
  }

  void _confirmDeleteSingle(SavedRoute route) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Route"),
        scrollable: true,
        content: Text("Are you sure you want to delete '${route.name}'?"),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: kDangerColor),
            onPressed: () {
              ref.read(savedRoutesProvider.notifier).deleteRoute(route);
              Navigator.pop(ctx);
            }, 
            child: const Text("Delete")
          ),
        ],
      ),
    );
  }

  void _confirmDeleteSelected(List<SavedRoute> routes) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Selection"),
        scrollable: true,
        content: Text("Delete ${_selectedKeys.length} selected routes?"),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: kDangerColor),
            onPressed: () {
              final toDelete = routes.where((r) => _selectedKeys.contains(r.key)).toList();
              ref.read(savedRoutesProvider.notifier).deleteRoutes(toDelete);
              setState(() => _selectedKeys.clear());
              Navigator.pop(ctx);
            }, 
            child: const Text("Delete All")
          ),
        ],
      ),
    );
  }

  void _confirmClearAll() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Clear All History"),
        scrollable: true,
        content: const Text("This cannot be undone. Delete everything?"),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: kDangerColor),
            onPressed: () {
              ref.read(savedRoutesProvider.notifier).clearAllRoutes();
              Navigator.pop(ctx);
            }, 
            child: const Text("Clear All")
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final routes = ref.watch(savedRoutesProvider);
    final isTracking = ref.watch(trackingProvider).isTracking;

    if (isTracking) return const ActiveTrackingView();

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      resizeToAvoidBottomInset: false, 
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            title: _isSelectionMode 
                ? Text("${_selectedKeys.length} Selected", style: const TextStyle(fontWeight: FontWeight.bold))
                : Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Route Memory", style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                      Row(
                        children: [
                          if (routes.isNotEmpty)
                            IconButton(
                              icon: const Icon(Icons.delete_sweep_outlined, color: Colors.grey),
                              tooltip: "Clear All History",
                              onPressed: _confirmClearAll,
                            ),
                          IconButton(
                            icon: const Icon(Icons.info_outline_rounded, color: Colors.grey),
                            tooltip: "About",
                            onPressed: _showAboutDialog,
                          ),
                        ],
                      ),
                    ],
                  ),
            centerTitle: false,
            elevation: 0,
            backgroundColor: kSurfaceColor,
            surfaceTintColor: kSurfaceColor,
            leading: _isSelectionMode 
                ? IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => _selectedKeys.clear()))
                : null,
            actions: [
              if (_isSelectionMode)
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: kDangerColor),
                  onPressed: () => _confirmDeleteSelected(routes),
                ),
              const SizedBox(width: 8),
            ],
          ),
          if (routes.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: kShadow),
                      child: Icon(Icons.map_rounded, size: 64, color: Colors.blue[100]),
                    ),
                    const SizedBox(height: 24),
                    Text("No routes yet", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[800])),
                    const SizedBox(height: 8),
                    Text("Hit the + button to start exploring.", style: TextStyle(color: Colors.grey[500])),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final route = routes[index];
                    final isSelected = _selectedKeys.contains(route.key);
                    return _buildRouteCard(route, isSelected);
                  },
                  childCount: routes.length,
                ),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
      floatingActionButton: _isSelectionMode 
          ? null 
          : FloatingActionButton.extended(
              onPressed: () => ref.read(trackingProvider.notifier).startTracking(),
              label: const Text("New Journey"),
              icon: const Icon(Icons.add_location_alt_outlined),
              backgroundColor: kPrimaryColor,
              foregroundColor: Colors.white,
              elevation: 4,
            ),
    );
  }

  Widget _buildRouteCard(SavedRoute route, bool isSelected) {
    final distStr = route.totalDistance > 1000 
        ? "${(route.totalDistance/1000).toStringAsFixed(2)} km"
        : "${route.totalDistance.toStringAsFixed(0)} m";

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isSelected ? Colors.blue[50] : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isSelected ? Border.all(color: kPrimaryColor, width: 2) : null,
        boxShadow: kShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onLongPress: () => _toggleSelection(route.key),
          onTap: () {
            if (_isSelectionMode) {
              _toggleSelection(route.key);
            } else {
              Navigator.push(context, MaterialPageRoute(builder: (_) => RouteDetailScreen(route: route)));
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 50, height: 50,
                  decoration: BoxDecoration(
                    color: isSelected ? kPrimaryColor : const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isSelected ? Icons.check : Icons.directions_walk_rounded, 
                    color: isSelected ? Colors.white : kPrimaryColor
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(route.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 4),
                      Text(
                        "${DateFormat.yMMMd().format(route.startTime)}  •  $distStr", 
                        style: TextStyle(fontSize: 13, color: Colors.grey[600], fontWeight: FontWeight.w500)
                      ),
                    ],
                  ),
                ),
                if (!_isSelectionMode)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 20, color: Colors.grey),
                        onPressed: () => _showRenameDialog(route),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 20, color: Colors.grey),
                        onPressed: () => _confirmDeleteSingle(route),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ActiveTrackingView extends ConsumerStatefulWidget {
  const ActiveTrackingView({super.key});
  @override
  ConsumerState<ActiveTrackingView> createState() => _ActiveTrackingViewState();
}

class _ActiveTrackingViewState extends ConsumerState<ActiveTrackingView> {
  final MapController _mapController = MapController();
  bool _shouldAutoCenter = true;
  bool _showReturnPath = false; 
  LatLng? _initialPos;
  bool _isMapReady = false;

  @override
  void initState() {
    super.initState();
  }

  void _onMapReady() {
    setState(() => _isMapReady = true);
    _initLocation();
  }

  Future<void> _initLocation() async {
    try {
      final lastPos = await Geolocator.getLastKnownPosition();
      if (lastPos != null && mounted && _isMapReady) {
        setState(() => _initialPos = LatLng(lastPos.latitude, lastPos.longitude));
        final trackingState = ref.read(trackingProvider);
        if (trackingState.currentPath.isEmpty) {
          _mapController.move(LatLng(lastPos.latitude, lastPos.longitude), 16.0);
        }
      }
    } catch (e) {
      debugPrint("Location Init Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final trackingState = ref.watch(trackingProvider);
    final LatLng displayPos;
    final bool hasLiveData = trackingState.currentPath.isNotEmpty;
    
    if (hasLiveData) {
      displayPos = trackingState.currentPath.last;
    } else if (_initialPos != null) {
      displayPos = _initialPos!;
    } else {
      displayPos = const LatLng(0, 0); 
    }

    final startPos = trackingState.currentPath.isNotEmpty ? trackingState.currentPath.first : null;
    
    ref.listen(trackingProvider, (prev, next) {
      if (_isMapReady && next.currentPath.isNotEmpty && _shouldAutoCenter && !_showReturnPath) {
         _mapController.move(next.currentPath.last, _mapController.camera.zoom);
      }
    });

    final dist = trackingState.totalDistanceMeters;
    final distDisplay = dist > 1000 ? "${(dist/1000).toStringAsFixed(2)} km" : "${dist.toStringAsFixed(0)} m";
    
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        resizeToAvoidBottomInset: false, 
        body: Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                onMapReady: _onMapReady, 
                initialCenter: displayPos, 
                initialZoom: 18.0,
                onPositionChanged: (_, hasGesture) {
                  if (hasGesture) setState(() => _shouldAutoCenter = false);
                },
              ),
              children: [
                TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.example.route_memory'),
                PolylineLayer(
                  polylines: [
                    Polyline(points: trackingState.currentPath, strokeWidth: 6.0, color: kPrimaryColor),
                    if (_showReturnPath && startPos != null)
                       Polyline(points: [displayPos, startPos], strokeWidth: 4.0, color: kDangerColor.withOpacity(0.8), isDotted: true),
                  ],
                ),
                MarkerLayer(markers: [
                  for (var cp in trackingState.checkpoints)
                    Marker(
                      point: LatLng(cp.latitude, cp.longitude), width: 40, height: 40,
                      child: const Icon(Icons.star, color: Colors.amber, size: 36),
                    ),
                  
                  Marker(
                    point: displayPos, 
                    width: 60, height: 60,
                    child: hasLiveData 
                      ? Transform.rotate(
                          angle: (trackingState.currentHeading * (math.pi / 180)),
                          child: Container(
                            decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8)]),
                            child: const Icon(Icons.arrow_upward_rounded, color: kPrimaryColor, size: 32),
                          ),
                        )
                      : Container( 
                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.8), shape: BoxShape.circle, boxShadow: [const BoxShadow(color: Colors.black12, blurRadius: 4)]),
                          child: const Icon(Icons.location_searching, color: Colors.grey, size: 30),
                        ),
                  ),
                ]),
              ],
            ),

            Positioned(
              top: MediaQuery.of(context).padding.top + 10, 
              left: 16, right: 16,
              child: Row(
                children: [
                  _buildBlurButton(
                    icon: Icons.close_rounded,
                    color: Colors.black87,
                    onTap: () => ref.read(trackingProvider.notifier).discardTracking(),
                  ),
                  const Spacer(),
                  if (!hasLiveData)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(20)),
                      child: const Row(
                        children: [
                          SizedBox(width: 10, height: 10, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                          SizedBox(width: 8),
                          Text("Locating...", style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  const Spacer(),
                  _buildBlurButton(
                    icon: Icons.flag_rounded,
                    color: Colors.amber[800]!,
                    onTap: () => _showCheckpointDialog(context, ref),
                  ),
                ],
              ),
            ),

            Positioned(
              bottom: 30, left: 16, right: 16,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: kCardRadius,
                  boxShadow: kShadow,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatItem("DISTANCE", distDisplay, Icons.directions_walk),
                        Container(width: 1, height: 30, color: Colors.grey[200]),
                        _buildStatItem("STOPS", "${trackingState.checkpoints.length}", Icons.pin_drop_outlined),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        InkWell(
                          onTap: () {
                             if (!_isMapReady) return;
                             setState(() { _shouldAutoCenter = true; _showReturnPath = false; });
                             if (trackingState.currentPath.isNotEmpty) _mapController.move(trackingState.currentPath.last, 18.0);
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: 50, height: 50,
                            decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12)),
                            child: Icon(_shouldAutoCenter ? Icons.gps_fixed : Icons.gps_not_fixed, color: Colors.grey[700]),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SizedBox(
                            height: 50,
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: kDangerColor,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: () => _handleStopAndSave(context, ref),
                              icon: const Icon(Icons.stop_rounded),
                              label: const Text("Finish Route", style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBlurButton({required IconData icon, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44, height: 44,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)],
        ),
        child: Icon(icon, color: color, size: 24),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(value.split(' ')[0], style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.black87)),
            if (value.contains(' '))
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Text(value.split(' ')[1], style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey[500])),
              ),
          ],
        ),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey[400], letterSpacing: 0.5)),
      ],
    );
  }

  void _showCheckpointDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Add Checkpoint"),
        scrollable: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: TextField(
          controller: controller, 
          decoration: InputDecoration(
            hintText: "Name this spot", 
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: Colors.grey[50],
          ), 
          autofocus: true
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          FilledButton(onPressed: () { if (controller.text.isNotEmpty) ref.read(trackingProvider.notifier).addCheckpoint(controller.text); Navigator.pop(ctx); }, child: const Text("Add")),
        ],
      ),
    );
  }

  void _handleStopAndSave(BuildContext context, WidgetRef ref) {
    final defaultName = "Route ${DateFormat('MMM dd, h:mm a').format(DateTime.now())}";
    final controller = TextEditingController(text: defaultName);
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Finish & Save"),
        scrollable: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Give your journey a memorable name:"),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              style: const TextStyle(fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                hintText: "e.g., Morning Run",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey[50],
                prefixIcon: const Icon(Icons.edit_road),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          FilledButton(
            onPressed: () {
              ref.read(trackingProvider.notifier).stopTracking(controller.text);
              Navigator.pop(ctx);
            },
            child: const Text("Save Route"),
          ),
        ],
      ),
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
              TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.example'),
              PolylineLayer(polylines: [
                Polyline(points: path, strokeWidth: 6.0, color: _isNavigating ? kPrimaryColor.withOpacity(0.5) : kPrimaryColor),
                if (_isNavigating && _navigationPath.isNotEmpty)
                  Polyline(points: _navigationPath, strokeWidth: 6.0, color: kAccentColor, isDotted: true),
              ]),
              if (!_isNavigating) MarkerLayer(markers: _getDirectionArrows()),
              MarkerLayer(markers: [
                _buildMarker(path.first, Icons.flag_rounded, kAccentColor, "START"),
                _buildMarker(path.last, Icons.flag_rounded, kDangerColor, "END"),
                for (var cp in widget.route.checkpoints) _buildMarker(LatLng(cp.latitude, cp.longitude), Icons.star_rounded, Colors.amber, cp.name),
                if (_userLocation != null) 
                  Marker(
                    point: _userLocation!, width: 60, height: 60, 
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.all(8),
        width: 44, height: 44,
        decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8)]),
        child: Icon(icon, color: color, size: 24),
      ),
    );
  }

  Marker _buildMarker(LatLng pos, IconData icon, Color color, String label) {
    return Marker(
      point: pos, width: 80, height: 80,
      child: GestureDetector(
        onTap: () => _showNavDialog(pos, label),
        child: Column(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4)]),
            child: Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
          ),
          Icon(icon, color: color, size: 40),
        ]),
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
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text("Navigating to $_targetName", style: TextStyle(color: Colors.grey[500], fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                  Text(_timeRemaining.inMinutes.toString(), style: const TextStyle(fontSize: 42, fontWeight: FontWeight.w800, color: Colors.black)),
                  const Text(" min", style: TextStyle(fontSize: 18, color: Colors.grey, fontWeight: FontWeight.w600)),
                ]),
                Text("${(_distanceRemaining/1000).toStringAsFixed(2)} km remaining", style: const TextStyle(fontSize: 16, color: Colors.black54, fontWeight: FontWeight.w500)),
              ]),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: kAccentColor.withOpacity(0.1), shape: BoxShape.circle),
              child: const Icon(Icons.directions_walk_rounded, size: 32, color: kAccentColor),
            )
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildInfoItem(Icons.access_time_rounded, "Time", DateFormat('h:mm a').format(widget.route.startTime)),
                _buildInfoItem(Icons.straighten_rounded, "Dist", "${(widget.route.totalDistance/1000).toStringAsFixed(2)} km"),
                _buildInfoItem(Icons.flag_rounded, "Stops", "${widget.route.checkpoints.length}"),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: kPrimaryColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                icon: const Icon(Icons.navigation_rounded),
                label: const Text("Start Guidance", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                onPressed: () {
                  final start = widget.route.points.first;
                  _showNavDialog(LatLng(start.latitude, start.longitude), "Start Point");
                },
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, color: Colors.grey[400], size: 24),
        const SizedBox(height: 8),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 12, fontWeight: FontWeight.w600)),
      ],
    );
  }

  void _showNavDialog(LatLng target, String name) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 24),
              Text("Navigate to $name?", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text("This will guide you along the recorded path back to $name.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600], fontSize: 16)),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      onPressed: () => Navigator.pop(ctx), 
                      child: const Text("Cancel")
                    )
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: kPrimaryColor, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      onPressed: () { Navigator.pop(ctx); _startNavigation(target, name); }, 
                      child: const Text("Let's Go")
                    )
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_compass/flutter_compass.dart';
import '../logic/settings_provider.dart';
import 'constants.dart';
import 'widgets/user_location_marker.dart';

class NavigationStep {
  final String instruction;
  final double distance;
  final String maneuverType;
  final String modifier;
  NavigationStep({required this.instruction, required this.distance, required this.maneuverType, required this.modifier});
}

class NavigationScreen extends ConsumerStatefulWidget {
  final LatLng target;
  final String targetName;
  const NavigationScreen({super.key, required this.target, required this.targetName});

  @override
  ConsumerState<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends ConsumerState<NavigationScreen> with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  LatLng? _userLocation;
  
  double _prevHeading = 0.0;
  bool _isHeadsUpMode = false;
  double _currentSpeed = 0.0;
  bool _shouldAutoCenter = true;

  List<LatLng> _routePath = [];
  Duration _timeRemaining = Duration.zero;
  double _distanceRemaining = 0.0;
  StreamSubscription<Position>? _positionStream;
  StreamSubscription<CompassEvent>? _compassStream;
  bool _isMapReady = false;
  LatLng? _lastFetchPos;
  
  // Loading State
  bool _isRouteLoading = true;
  
  List<NavigationStep> _steps = [];
  NavigationStep? _currentStep;

  @override
  void initState() {
    super.initState();
    _startNavigation();
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

  void _startNavigation() async {
    // 1. Check Permissions
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) Navigator.pop(context); // Exit if denied
        return;
      }
    }

    // 2. Get Initial Position & Route
    try {
      final initialPos = await Geolocator.getCurrentPosition();
      if (mounted) {
        final startLatLng = LatLng(initialPos.latitude, initialPos.longitude);
        _userLocation = startLatLng;
        // Fetch the initial route before hiding the loading screen
        await _fetchRoadRoute(startLatLng, widget.target);
        
        if (mounted) {
          setState(() {
            _lastFetchPos = startLatLng;
            _isRouteLoading = false; // Stop loading only after we have data
          });
        }
      }
    } catch (e) { 
      debugPrint("Error getting initial pos: $e");
      if (mounted) setState(() => _isRouteLoading = false);
    }

    // 3. Start Stream
    LocationSettings locationSettings;
    if (defaultTargetPlatform == TargetPlatform.android) {
      locationSettings = AndroidSettings(accuracy: LocationAccuracy.bestForNavigation, distanceFilter: 0, forceLocationManager: true, intervalDuration: const Duration(milliseconds: 500));
    } else {
      locationSettings = const LocationSettings(accuracy: LocationAccuracy.bestForNavigation, distanceFilter: 0);
    }

    _positionStream = Geolocator.getPositionStream(locationSettings: locationSettings).listen((Position position) {
      final userPos = LatLng(position.latitude, position.longitude);
      _currentSpeed = position.speed; 

      if (mounted) {
        // If we somehow got a stream update before the initial fetch finished, ensure loading is off and location is set
        bool wasLoading = _isRouteLoading;
        setState(() {
          _userLocation = userPos;
          if (wasLoading) _isRouteLoading = false;
        });
        
        if (_isMapReady && _shouldAutoCenter) {
          if (_isHeadsUpMode) {
             _mapController.moveAndRotate(userPos, 18.0, -_prevHeading);
          } else {
             _mapController.move(userPos, 18.0);
          }
        }
        _updateRoute(userPos);
        _updateCurrentStep(userPos);
      }
    });
  }

  void _updateCurrentStep(LatLng userPos) {
    if (_steps.isNotEmpty) setState(() => _currentStep = _steps.first);
  }

  Future<void> _updateRoute(LatLng userPos, {bool force = false}) async {
    if (force || _lastFetchPos == null || const Distance().as(LengthUnit.Meter, _lastFetchPos!, userPos) > 30) {
      await _fetchRoadRoute(userPos, widget.target);
      if (mounted) setState(() => _lastFetchPos = userPos);
    }
  }

  Future<void> _fetchRoadRoute(LatLng start, LatLng end) async {
    try {
      final url = Uri.https('router.project-osrm.org', '/route/v1/driving/${start.longitude},${start.latitude};${end.longitude},${end.latitude}', {'overview': 'full', 'geometries': 'geojson', 'steps': 'true'});
      final request = await HttpClient().getUrl(url);
      request.headers.set(HttpHeaders.userAgentHeader, 'RouteMemoryApp/1.0');
      final response = await request.close();
      if (response.statusCode == 200) {
        final jsonString = await response.transform(utf8.decoder).join();
        final data = jsonDecode(jsonString);
        if (data['routes'] != null && (data['routes'] as List).isNotEmpty) {
          final route = data['routes'][0];
          final coordinates = route['geometry']['coordinates'] as List;
          List<NavigationStep> newSteps = [];
          if (route['legs'] != null && route['legs'].isNotEmpty) {
            final stepsJson = route['legs'][0]['steps'] as List;
            for (var s in stepsJson) {
              newSteps.add(NavigationStep(instruction: s['maneuver']['type'] == 'arrive' ? "Arrive" : (s['name'] != null ? "Turn onto ${s['name']}" : "Continue"), distance: (s['distance'] as num).toDouble(), maneuverType: s['maneuver']['type'] ?? '', modifier: s['maneuver']['modifier'] ?? ''));
            }
          }
          if (mounted) {
            setState(() {
              _routePath = coordinates.map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble())).toList();
              final durationSeconds = (route['duration'] as num).toDouble();
              _distanceRemaining = (route['distance'] as num).toDouble();
              _timeRemaining = Duration(seconds: durationSeconds.toInt());
              _steps = newSteps;
              if (_steps.isNotEmpty && _currentStep == null) _currentStep = _steps.first;
            });
          }
        }
      }
    } catch (e) { debugPrint("Router Error: $e"); }
  }

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
    if (_timeRemaining.inSeconds < 60) {
      return "${_timeRemaining.inSeconds}s";
    }
    final mins = _timeRemaining.inMinutes;
    final secs = _timeRemaining.inSeconds % 60;
    if (secs == 0) return "${mins}m";
    return "${mins}m ${secs}s";
  }

  Widget _buildLoadingScreen(ThemeData theme) {
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("Navigation"),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.iconTheme.color),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 50,
              height: 50,
              child: CircularProgressIndicator(strokeWidth: 3, color: kPrimaryColor),
            ),
            const SizedBox(height: 24),
            Text(
              "Calculating Route...",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: theme.textTheme.bodyMedium?.color),
            ),
            const SizedBox(height: 8),
            Text(
              "Acquiring GPS & Traffic Data",
              style: TextStyle(color: theme.textTheme.bodySmall?.color),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mapSettings = ref.watch(settingsProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    // Check Loading State
    if (_isRouteLoading || _userLocation == null) {
      return _buildLoadingScreen(theme);
    }

    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final distStr = ref.read(settingsProvider.notifier).getFormattedDistance(_distanceRemaining);
    final isNavigating = _currentStep != null;

    final interactionFlags = _isHeadsUpMode 
        ? mapSettings.interactionFlags & ~InteractiveFlag.rotate 
        : mapSettings.interactionFlags;

    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _userLocation ?? widget.target, 
              initialZoom: 18.0,
              interactionOptions: InteractionOptions(flags: interactionFlags),
              onMapReady: () async {
                setState(() => _isMapReady = true);
                if (_userLocation != null) _mapController.move(_userLocation!, 18.0);
              },
              onPositionChanged: (pos, hasGesture) { if (hasGesture) setState(() => _shouldAutoCenter = false); },
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
                TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.sasidharakurathi.routememory', retinaMode: mapSettings.retinaMode, panBuffer: mapSettings.panBuffer),
              
              if (_routePath.isNotEmpty) PolylineLayer(polylines: [Polyline(points: _routePath, strokeWidth: 8.0, color: kAccentColor.withOpacity(0.8), strokeJoin: StrokeJoin.round)]),
              MarkerLayer(markers: [
                Marker(point: widget.target, width: 80, height: 80, child: const Icon(Icons.location_on, color: kDangerColor, size: 50)),
                if (_userLocation != null) 
                  Marker(
                    point: _userLocation!, 
                    width: 60, height: 60, 
                    child: const RepaintBoundary(child: UserLocationMarker())
                  )
              ])
            ]
          ),
          
          if (!isNavigating) Positioned(top: topPadding + 16, left: 16, child: _buildBlurButton(icon: Icons.arrow_back, onTap: () => Navigator.pop(context), theme: theme)),
          Positioned(top: topPadding + 16, right: 16, child: Column(children: [_buildBlurButton(icon: _isHeadsUpMode ? Icons.explore : Icons.explore_off, color: _isHeadsUpMode ? kPrimaryColor : (isDark ? Colors.white : Colors.black87), onTap: _toggleHeadsUpMode, theme: theme), const SizedBox(height: 12), _buildBlurButton(icon: Icons.my_location, color: _shouldAutoCenter ? kPrimaryColor : (isDark ? Colors.white54 : Colors.grey), onTap: _recenterMap, theme: theme)])),

          Positioned(bottom: 30 + bottomPadding, left: 16, right: 16, child: Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: theme.cardColor, borderRadius: kCardRadius, boxShadow: kShadow), child: Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text("Navigating to", style: TextStyle(color: isDark ? Colors.white54 : Colors.grey[500], fontSize: 12, fontWeight: FontWeight.w600)), Text(widget.targetName, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: theme.textTheme.bodyMedium?.color)), const SizedBox(height: 4), Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
            Text(_formatTimeRemaining(), style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: kPrimaryColor)), 
            const SizedBox(width: 12), 
            Text(distStr, style: TextStyle(fontSize: 16, color: isDark ? Colors.white70 : Colors.black54, fontWeight: FontWeight.w500))
          ])])), GestureDetector(onTap: () { Navigator.pop(context); }, child: Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: kDangerColor.withOpacity(0.1), shape: BoxShape.circle), child: Icon(Icons.close, size: 28, color: kDangerColor)))]))),
        ]
      ),
    );
  }

  Widget _buildBlurButton({required IconData icon, Color? color, required VoidCallback onTap, required ThemeData theme}) {
    return GestureDetector(onTap: onTap, child: Container(margin: const EdgeInsets.all(8), width: 44, height: 44, decoration: BoxDecoration(color: theme.cardColor, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8)]), child: Icon(icon, color: color ?? theme.iconTheme.color, size: 24)));
  }
}
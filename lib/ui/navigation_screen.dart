import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'constants.dart';

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
    path.moveTo(size.width / 2 - 8, 0);
    path.lineTo(size.width / 2 + 8, 0);
    path.lineTo(size.width / 2, size.height);
    path.close();

    canvas.drawPath(path, paint);

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

class NavigationScreen extends StatefulWidget {
  final LatLng target;
  final String targetName;
  const NavigationScreen({super.key, required this.target, required this.targetName});

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  final MapController _mapController = MapController();
  LatLng? _userLocation;
  double _currentHeading = 0.0;
  List<LatLng> _routePath = [];
  Duration _timeRemaining = Duration.zero;
  double _distanceRemaining = 0.0;
  StreamSubscription<Position>? _positionStream;
  bool _isMapReady = false;
  LatLng? _lastFetchPos;

  @override
  void initState() {
    super.initState();
    _startNavigation();
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    super.dispose();
  }

  void _startNavigation() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    LocationSettings locationSettings;
    if (defaultTargetPlatform == TargetPlatform.android) {
      locationSettings = AndroidSettings(accuracy: LocationAccuracy.bestForNavigation, distanceFilter: 0, forceLocationManager: true, intervalDuration: const Duration(seconds: 1));
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      locationSettings = AppleSettings(accuracy: LocationAccuracy.bestForNavigation, activityType: ActivityType.fitness, distanceFilter: 0, pauseLocationUpdatesAutomatically: false, showBackgroundLocationIndicator: true);
    } else {
      locationSettings = const LocationSettings(accuracy: LocationAccuracy.bestForNavigation, distanceFilter: 0);
    }

    _positionStream = Geolocator.getPositionStream(locationSettings: locationSettings).listen((Position position) {
      final userPos = LatLng(position.latitude, position.longitude);
      double newHeading = position.heading;
      if (newHeading == 0.0 && _userLocation != null) {
        final dist = const Distance().as(LengthUnit.Meter, _userLocation!, userPos);
        if (dist > 0.5) {
          newHeading = Geolocator.bearingBetween(_userLocation!.latitude, _userLocation!.longitude, userPos.latitude, userPos.longitude);
        } else {
          newHeading = _currentHeading;
        }
      }
      if (mounted) {
        setState(() {
          _userLocation = userPos;
          _currentHeading = newHeading;
        });
        _updateRoute(userPos);
      }
    });
  }

  Future<void> _updateRoute(LatLng userPos) async {
    if (_lastFetchPos == null || const Distance().as(LengthUnit.Meter, _lastFetchPos!, userPos) > 20) {
      final newPath = await _fetchRoadRoute(userPos, widget.target);
      if (mounted) {
        setState(() {
          _routePath = newPath;
          _lastFetchPos = userPos;
          _distanceRemaining = _calculatePathDistance(newPath);
          _timeRemaining = Duration(seconds: (_distanceRemaining / 1.4).round());
        });
      }
    }
  }

  Future<List<LatLng>> _fetchRoadRoute(LatLng start, LatLng end) async {
    try {
      final url = Uri.https('router.project-osrm.org', '/route/v1/driving/${start.longitude},${start.latitude};${end.longitude},${end.latitude}', {'overview': 'full', 'geometries': 'geojson'});
      final request = await HttpClient().getUrl(url);
      request.headers.set(HttpHeaders.userAgentHeader, 'RouteMemoryApp/1.0 (flutter_student_project)');
      final response = await request.close();
      if (response.statusCode == 200) {
        final jsonString = await response.transform(utf8.decoder).join();
        final data = jsonDecode(jsonString);
        if (data['routes'] != null && (data['routes'] as List).isNotEmpty) {
          final coordinates = data['routes'][0]['geometry']['coordinates'] as List;
          return coordinates.map((c) => LatLng(c[1], c[0])).toList();
        }
      }
    } catch (e) {
      debugPrint("Router Error: $e");
    }
    return [start, end];
  }

  double _calculatePathDistance(List<LatLng> path) {
    double totalDist = 0;
    const distance = Distance();
    for (int i = 0; i < path.length - 1; i++) {
      totalDist += distance.as(LengthUnit.Meter, path[i], path[i + 1]);
    }
    return totalDist;
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return Scaffold(
      body: Stack(children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: widget.target,
            initialZoom: 16.0,
            onMapReady: () async {
              setState(() => _isMapReady = true);
              final pos = await Geolocator.getLastKnownPosition();
              if (pos != null) _mapController.move(LatLng(pos.latitude, pos.longitude), 18.0);
            }
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.sasidharakurathi.route_memory',
              retinaMode: true,
              maxNativeZoom: 19,
            ),
            if (_routePath.isNotEmpty) PolylineLayer(polylines: [Polyline(points: _routePath, strokeWidth: 6.0, color: kAccentColor, isDotted: true)]),
            MarkerLayer(markers: [
              Marker(
                point: widget.target,
                width: 100,
                height: 100,
                alignment: const Alignment(0.0, -0.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: kDangerColor,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(20),
                          topRight: Radius.circular(20),
                          bottomLeft: Radius.circular(12),
                          bottomRight: Radius.circular(12),
                        ),
                        boxShadow: [
                          BoxShadow(color: kDangerColor.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 4)),
                        ],
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(Icons.location_on, color: Colors.white, size: 24),
                    ),
                    CustomPaint(
                      size: const Size(40, 10),
                      painter: _PinTipPainter(color: kDangerColor),
                    ),
                    if (widget.targetName.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: kDangerColor, width: 0.5),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2)),
                            ],
                          ),
                          child: Text(
                            widget.targetName,
                            style: TextStyle(
                              color: kDangerColor,
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
              if (_userLocation != null)
                Marker(
                  point: _userLocation!, 
                  width: 60, 
                  height: 60, 
                  alignment: Alignment.center,
                  child: Transform.rotate(
                    angle: (_currentHeading * (math.pi / 180)), 
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white, 
                        shape: BoxShape.circle, 
                        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8)]
                      ), 
                      child: const Icon(Icons.arrow_upward_rounded, color: kPrimaryColor, size: 32)
                    )
                  )
                )
            ])
          ]
        ),
        Positioned(top: MediaQuery.of(context).padding.top + 10, left: 16, child: GestureDetector(onTap: () => Navigator.pop(context), child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: kShadow), child: const Icon(Icons.arrow_back, color: Colors.black)))),
        Positioned(bottom: 30 + bottomPadding, left: 16, right: 16, child: Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.white, borderRadius: kCardRadius, boxShadow: kShadow), child: Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text("Navigating to", style: TextStyle(color: Colors.grey[500], fontSize: 12, fontWeight: FontWeight.w600)), Text(widget.targetName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)), const SizedBox(height: 4), Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [Text(_timeRemaining.inMinutes.toString(), style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: kPrimaryColor)), const Text(" min", style: TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.w600)), const SizedBox(width: 12), Text("${(_distanceRemaining / 1000).toStringAsFixed(2)} km", style: const TextStyle(fontSize: 16, color: Colors.black54, fontWeight: FontWeight.w500))])])), GestureDetector(onTap: () { if (_userLocation != null) _mapController.move(_userLocation!, 18.0); }, child: Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: kPrimaryColor.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.navigation, size: 28, color: kPrimaryColor)))]))),
      ]),
    );
  }
}
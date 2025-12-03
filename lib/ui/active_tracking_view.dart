import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;
import 'package:geolocator/geolocator.dart';

import '../logic/tracking_provider.dart';
import '../logic/location_provider.dart';
import 'constants.dart';

// --- CONSTANTS ---
Color _getCategoryColor(String category) {
  final colors = [
    Colors.blue, Colors.red, Colors.green, Colors.orange,
    Colors.purple, Colors.teal, Colors.pink, Colors.indigo,
    Colors.brown, Colors.cyan, Colors.deepOrange
  ];
  return colors[category.hashCode.abs() % colors.length];
}

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

class ActiveTrackingView extends ConsumerStatefulWidget {
  final LatLng? initialTarget;
  final String? initialTargetName;
  const ActiveTrackingView(
      {super.key, this.initialTarget, this.initialTargetName});
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
        setState(
            () => _initialPos = LatLng(lastPos.latitude, lastPos.longitude));
        final trackingState = ref.read(trackingProvider);
        if (trackingState.currentPath.isEmpty)
          _mapController.move(
              LatLng(lastPos.latitude, lastPos.longitude), 16.0);
      }
    } catch (e) {}
  }

  @override
  Widget build(BuildContext context) {
    final trackingState = ref.watch(trackingProvider);
    final savedLocationsAsync = ref.watch(savedLocationsProvider);
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final LatLng displayPos = trackingState.currentPath.isNotEmpty
        ? trackingState.currentPath.last
        : (_initialPos ?? const LatLng(0, 0));
    final startPos = trackingState.currentPath.isNotEmpty
        ? trackingState.currentPath.first
        : null;
    final hasLiveData = trackingState.currentPath.isNotEmpty;
    final distDisplay = trackingState.totalDistanceMeters > 1000
        ? "${(trackingState.totalDistanceMeters / 1000).toStringAsFixed(2)} km"
        : "${trackingState.totalDistanceMeters.toStringAsFixed(0)} m";

    ref.listen(trackingProvider, (prev, next) {
      if (_isMapReady &&
          next.currentPath.isNotEmpty &&
          _shouldAutoCenter &&
          !_showReturnPath) {
        _mapController.move(next.currentPath.last, _mapController.camera.zoom);
      }
    });

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
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.route_memory',
                  retinaMode: true,
                  maxNativeZoom: 19, // FIX ADDED
                ),
                PolylineLayer(polylines: [
                  Polyline(
                      points: trackingState.currentPath,
                      strokeWidth: 6.0,
                      color: kPrimaryColor),
                  if (_showReturnPath && startPos != null)
                    Polyline(
                        points: [displayPos, startPos],
                        strokeWidth: 4.0,
                        color: kDangerColor.withOpacity(0.8),
                        isDotted: true)
                ]),
                savedLocationsAsync.when(
                    data: (locs) => MarkerLayer(
                        markers: locs
                            .map((l) => Marker(
                                point: LatLng(l.latitude, l.longitude),
                                width: 100,
                                height: 100,
                                alignment: const Alignment(0.0, 0.0),
                                child: GestureDetector(
                                  onTap: () {},
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: _getCategoryColor(l.category),
                                          borderRadius: const BorderRadius.only(
                                            topLeft: Radius.circular(20),
                                            topRight: Radius.circular(20),
                                            bottomLeft: Radius.circular(12),
                                            bottomRight: Radius.circular(12),
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                                color: _getCategoryColor(l.category)
                                                    .withOpacity(0.4),
                                                blurRadius: 8,
                                                offset: const Offset(0, 4)),
                                          ],
                                          border: Border.all(
                                              color: Colors.white, width: 2),
                                        ),
                                        child: Icon(Icons.bookmark_rounded,
                                            color: Colors.white,
                                            size: 22),
                                      ),
                                      CustomPaint(
                                        size: const Size(40, 10),
                                        painter: _PinTipPainter(
                                            color: _getCategoryColor(l.category)),
                                      ),
                                      if (l.name.isNotEmpty)
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(top: 4),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              border: Border.all(
                                                  color: _getCategoryColor(l.category),
                                                  width: 0.5),
                                              boxShadow: [
                                                BoxShadow(
                                                    color: Colors.black
                                                        .withOpacity(0.1),
                                                    blurRadius: 4,
                                                    offset: const Offset(0, 2)),
                                              ],
                                            ),
                                            child: Text(
                                              l.name,
                                              style: TextStyle(
                                                color: _getCategoryColor(l.category),
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
                                )))
                            .toList()),
                    loading: () => const MarkerLayer(markers: []),
                    error: (_, __) => const MarkerLayer(markers: [])),
                MarkerLayer(markers: [
                  for (var cp in trackingState.checkpoints)
                    Marker(
                      point: LatLng(cp.latitude, cp.longitude),
                      width: 100,
                      height: 100,
                      alignment: const Alignment(0.0, 0.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.amber,
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(20),
                                topRight: Radius.circular(20),
                                bottomLeft: Radius.circular(12),
                                bottomRight: Radius.circular(12),
                              ),
                              boxShadow: [
                                BoxShadow(
                                    color: Colors.amber.withOpacity(0.4),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4)),
                              ],
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Center(
                              child: Icon(Icons.star,
                                  color: Colors.white, size: 22),
                            ),
                          ),
                          CustomPaint(
                            size: const Size(40, 10),
                            painter: _PinTipPainter(color: Colors.amber),
                          ),
                          if (cp.name.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: Colors.amber, width: 0.5),
                                  boxShadow: [
                                    BoxShadow(
                                        color: Colors.black.withOpacity(0.1),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2)),
                                  ],
                                ),
                                child: Text(
                                  cp.name,
                                  style: const TextStyle(
                                    color: Colors.amber,
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
                  Marker(
                      point: displayPos,
                      width: 60,
                      height: 60,
                      alignment: Alignment.center,
                      child: hasLiveData
                          ? Transform.rotate(
                              angle: (trackingState.currentHeading *
                                  (math.pi / 180)),
                              child: Container(
                                  decoration: BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                            color: Colors.black26,
                                            blurRadius: 8)
                                      ]),
                                  child: const Icon(Icons.arrow_upward_rounded,
                                      color: kPrimaryColor, size: 32)))
                          : Container(
                              decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.8),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    const BoxShadow(
                                        color: Colors.black12, blurRadius: 4)
                                  ]),
                              child: const Icon(Icons.location_searching,
                                  color: Colors.grey, size: 30))),
                ]),
              ],
            ),
            Positioned(
                top: MediaQuery.of(context).padding.top + 10,
                left: 16,
                right: 16,
                child: Row(children: [
                  _buildBlurButton(
                      icon: Icons.close_rounded,
                      color: Colors.black87,
                      onTap: () => ref
                          .read(trackingProvider.notifier)
                          .discardTracking()),
                  const Spacer(),
                  if (!hasLiveData)
                    Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                            color: Colors.black87,
                            borderRadius: BorderRadius.circular(20)),
                        child: const Row(children: [
                          SizedBox(
                              width: 10,
                              height: 10,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white)),
                          SizedBox(width: 8),
                          Text("Locating...",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold))
                        ])),
                  const Spacer(),
                  _buildBlurButton(
                      icon: Icons.flag_rounded,
                      color: Colors.amber[800]!,
                      onTap: () => _showCheckpointDialog(context, ref))
                ])),
            Positioned(
                bottom: 30 + bottomPadding,
                left: 16,
                right: 16,
                child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: kCardRadius,
                        boxShadow: kShadow),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildStatItem(
                                "DISTANCE", distDisplay, Icons.directions_walk),
                            Container(
                                width: 1, height: 30, color: Colors.grey[200]),
                            _buildStatItem(
                                "STOPS",
                                "${trackingState.checkpoints.length}",
                                Icons.pin_drop_outlined)
                          ]),
                      const SizedBox(height: 20),
                      Row(children: [
                        InkWell(
                            onTap: () {
                              if (!_isMapReady) return;
                              setState(() {
                                _shouldAutoCenter = true;
                                _showReturnPath = false;
                              });
                              if (trackingState.currentPath.isNotEmpty)
                                _mapController.move(
                                    trackingState.currentPath.last, 18.0);
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                    color: Colors.grey[100],
                                    borderRadius: BorderRadius.circular(12)),
                                child: Icon(
                                    _shouldAutoCenter
                                        ? Icons.gps_fixed
                                        : Icons.gps_not_fixed,
                                    color: Colors.grey[700]))),
                        const SizedBox(width: 12),
                        Expanded(
                            child: SizedBox(
                                height: 50,
                                child: FilledButton.icon(
                                    style: FilledButton.styleFrom(
                                        backgroundColor: kDangerColor,
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12))),
                                    onPressed: () =>
                                        _handleStopAndSave(context, ref),
                                    icon: const Icon(Icons.stop_rounded),
                                    label: const Text("Finish Route",
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold))))),
                      ])
                    ]))),
          ],
        ),
      ),
    );
  }

  Widget _buildBlurButton(
      {required IconData icon,
      Color color = Colors.black87,
      required VoidCallback onTap}) {
    return GestureDetector(
        onTap: onTap,
        child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.1), blurRadius: 10)
                ]),
            child: Icon(icon, color: color, size: 24)));
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(children: [
      Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(value.split(' ')[0],
                style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Colors.black87)),
            if (value.contains(' '))
              Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Text(value.split(' ')[1],
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[500])))
          ]),
      const SizedBox(height: 2),
      Text(label,
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.grey[400],
              letterSpacing: 0.5))
    ]);
  }

  void _showCheckpointDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
                title: const Text("Add Checkpoint"),
                scrollable: true,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                content: TextField(
                    controller: controller,
                    decoration: InputDecoration(
                        hintText: "Name this spot",
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: Colors.grey[50]),
                    autofocus: true),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text("Cancel")),
                  FilledButton(
                      onPressed: () {
                        if (controller.text.isNotEmpty)
                          ref
                              .read(trackingProvider.notifier)
                              .addCheckpoint(controller.text);
                        Navigator.pop(ctx);
                      },
                      child: const Text("Add"))
                ]));
  }

  void _handleStopAndSave(BuildContext context, WidgetRef ref) {
    final defaultName =
        "Route ${DateFormat('MMM dd, h:mm a').format(DateTime.now())}";
    final controller = TextEditingController(text: defaultName);
    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
                title: const Text("Finish & Save"),
                scrollable: true,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
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
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              filled: true,
                              fillColor: Colors.grey[50],
                              prefixIcon: const Icon(Icons.edit_road)))
                    ]),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text("Cancel")),
                  FilledButton(
                      onPressed: () {
                        ref
                            .read(trackingProvider.notifier)
                            .stopTracking(controller.text);
                        Navigator.pop(ctx);
                      },
                      child: const Text("Save Route"))
                ]));
  }
}

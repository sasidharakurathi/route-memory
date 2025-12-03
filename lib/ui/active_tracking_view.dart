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
import '../logic/settings_provider.dart';
import 'constants.dart';
import 'widgets/user_location_marker.dart';


Color _getCategoryColor(String category) {
  final colors = [
    Colors.blue, Colors.red, Colors.green, Colors.orange,
    Colors.purple, Colors.teal, Colors.pink, Colors.indigo,
    Colors.brown, Colors.cyan, Colors.deepOrange
  ];
  return colors[category.hashCode.abs() % colors.length];
}


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

class ActiveTrackingView extends ConsumerStatefulWidget {
  const ActiveTrackingView({super.key});
  @override
  ConsumerState<ActiveTrackingView> createState() => _ActiveTrackingViewState();
}

class _ActiveTrackingViewState extends ConsumerState<ActiveTrackingView> {
  final MapController _mapController = MapController();
  bool _shouldAutoCenter = true;
  bool _isMapReady = false;
  Timer? _timer;
  Duration _duration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return; 
      
      final state = ref.read(trackingProvider);
      if (state.rawPoints.isNotEmpty) {
        final startTime = state.rawPoints.first.timestamp;
        setState(() {
          _duration = DateTime.now().difference(startTime);
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(d.inHours);
    final minutes = twoDigits(d.inMinutes.remainder(60));
    final seconds = twoDigits(d.inSeconds.remainder(60));
    return "$hours:$minutes:$seconds";
  }

  void _recenterMap() {
    setState(() => _shouldAutoCenter = true);
    final trackingState = ref.read(trackingProvider);
    if (trackingState.currentPath.isNotEmpty) {
      _mapController.move(trackingState.currentPath.last, 18.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    
    final mapSettings = ref.watch(settingsProvider);
    final trackingState = ref.watch(trackingProvider);
    final savedLocationsAsync = ref.watch(savedLocationsProvider);
    
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final topPadding = MediaQuery.of(context).padding.top;
    
    
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    ref.listen(trackingProvider, (prev, next) {
      if (_isMapReady && next.currentPath.isNotEmpty && _shouldAutoCenter) {
        _mapController.move(next.currentPath.last, _mapController.camera.zoom);
      }
    });

    final LatLng displayPos = trackingState.currentPath.isNotEmpty 
        ? trackingState.currentPath.last 
        : const LatLng(0, 0);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      
      value: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        body: Stack(
          children: [
            
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                onMapReady: () => setState(() => _isMapReady = true),
                initialCenter: displayPos, 
                initialZoom: 18.0,
                interactionOptions: InteractionOptions(flags: mapSettings.interactionFlags),
                onPositionChanged: (_, hasGesture) { 
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
                PolylineLayer(polylines: [
                  Polyline(
                    points: trackingState.currentPath,
                    strokeWidth: 6.0,
                    color: kPrimaryColor,
                    strokeJoin: StrokeJoin.round,
                  )
                ]),
                MarkerLayer(markers: [
                  
                  ...savedLocationsAsync.when(
                    data: (locs) => locs.map((l) {
                      final color = _getCategoryColor(l.category);
                      return Marker(
                        point: LatLng(l.latitude, l.longitude),
                        width: 100, 
                        height: 100,
                        alignment: const Alignment(0.0, 0.0),
                        child: Tooltip(
                          message: l.name,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 40, height: 40,
                                decoration: BoxDecoration(
                                  color: color,
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(20), topRight: Radius.circular(20),
                                    bottomLeft: Radius.circular(12), bottomRight: Radius.circular(12),
                                  ),
                                  boxShadow: [BoxShadow(color: color.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 4))],
                                  border: Border.all(color: Colors.white, width: 2),
                                ),
                                child: const Icon(Icons.location_on, color: Colors.white, size: 22),
                              ),
                              CustomPaint(size: const Size(40, 10), painter: _PinTipPainter(color: color)),
                            ],
                          ),
                        ),
                      );
                    }),
                    loading: () => [],
                    error: (_,__) => [],
                  ),

                  
                  for (var cp in trackingState.checkpoints)
                    Marker(
                      point: LatLng(cp.latitude, cp.longitude),
                      width: 40, height: 40,
                      child: const Icon(Icons.flag, color: Colors.orange, size: 30),
                    ),
                  
                  
                  if (trackingState.currentPath.isNotEmpty)
                    Marker(
                      point: displayPos,
                      width: 60, height: 60,
                      child: const UserLocationMarker()
                    ),
                ]),
              ],
            ),

            
            Positioned(
              top: topPadding + 16, 
              left: 16,
              child: _buildBlurButton(
                icon: Icons.close_rounded,
                onTap: () => _confirmDiscard(context, ref),
                theme: theme 
              )
            ),

            Positioned(
              top: topPadding + 16, 
              right: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _buildBlurButton(
                    icon: Icons.flag_rounded, 
                    color: Colors.orange,
                    onTap: () => _showCheckpointDialog(context, ref),
                    theme: theme
                  ),
                  const SizedBox(height: 12),
                  _buildBlurButton(
                    icon: Icons.my_location,
                    
                    color: _shouldAutoCenter ? kPrimaryColor : (isDark ? Colors.white54 : Colors.black87),
                    onTap: _recenterMap,
                    theme: theme
                  ),
                ],
              )
            ),

            
            Positioned(
              bottom: 30 + bottomPadding, 
              left: 16, 
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(20), 
                decoration: BoxDecoration(
                  color: theme.cardColor, 
                  borderRadius: kCardRadius, 
                  boxShadow: kShadow
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start, 
                        children: [
                          Text(
                            "Recording Journey...", 
                            style: TextStyle(color: isDark ? Colors.white54 : Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _formatDuration(_duration), 
                            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: kPrimaryColor)
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "${ref.read(settingsProvider.notifier).getFormattedDistance(trackingState.totalDistanceMeters)}  •  ${trackingState.checkpoints.length} stops",
                            style: TextStyle(fontSize: 14, color: isDark ? Colors.white70 : Colors.black54, fontWeight: FontWeight.w600)
                          ),
                        ]
                      )
                    ), 
                    
                    const SizedBox(width: 16),
                    GestureDetector(
                      onTap: () => _handleStopAndSave(context, ref), 
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16), 
                        decoration: BoxDecoration(
                          color: kDangerColor, 
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(color: kDangerColor.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 4))
                          ]
                        ), 
                        child: const Icon(Icons.stop_rounded, size: 32, color: Colors.white)
                      )
                    )
                  ]
                )
              )
            )
          ],
        ),
      ),
    );
  }

  
  Widget _buildBlurButton({required IconData icon, Color? color, required VoidCallback onTap, required ThemeData theme}) {
    return GestureDetector(
      onTap: onTap, 
      child: Container(
        margin: const EdgeInsets.all(8), 
        width: 44, height: 44, 
        decoration: BoxDecoration(
          color: theme.cardColor, 
          shape: BoxShape.circle, 
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8)]
        ), 
        child: Icon(icon, color: color ?? theme.iconTheme.color, size: 24)
      )
    );
  }

  void _confirmDiscard(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context, 
      builder: (ctx) => AlertDialog(
        title: const Text("Discard Journey?"),
        content: const Text("This will stop recording and delete current data."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: kDangerColor),
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(trackingProvider.notifier).discardTracking();
            }, 
            child: const Text("Discard")
          ),
        ]
      )
    );
  }

  void _showCheckpointDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
                title: const Text("Add Checkpoint"),
                content: TextField(
                    controller: controller,
                    decoration: InputDecoration(
                        hintText: "Name this spot",
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: Theme.of(context).scaffoldBackgroundColor),
                    autofocus: true),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
                  FilledButton(
                      onPressed: () {
                        if (controller.text.isNotEmpty)
                          ref.read(trackingProvider.notifier).addCheckpoint(controller.text);
                        Navigator.pop(ctx);
                      },
                      child: const Text("Add"))
                ]));
  }

  void _handleStopAndSave(BuildContext context, WidgetRef ref) {
    final defaultName = "Route ${DateFormat('MMM dd, h:mm a').format(DateTime.now())}";
    final controller = TextEditingController(text: defaultName);
    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
                title: const Text("Finish & Save"),
                content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text("Give your journey a name:"),
                      const SizedBox(height: 12),
                      TextField(
                          controller: controller,
                          autofocus: true,
                          decoration: InputDecoration(
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              filled: true,
                              fillColor: Theme.of(context).scaffoldBackgroundColor))
                    ]),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
                  FilledButton(
                      onPressed: () {
                        ref.read(trackingProvider.notifier).stopTracking(controller.text);
                        Navigator.pop(ctx);
                      },
                      child: const Text("Save"))
                ]));
  }
}
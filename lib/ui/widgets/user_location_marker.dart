import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'dart:async';

class UserLocationMarker extends StatefulWidget {
  const UserLocationMarker({super.key});

  @override
  State<UserLocationMarker> createState() => _UserLocationMarkerState();
}

class _UserLocationMarkerState extends State<UserLocationMarker> with SingleTickerProviderStateMixin {
  
  
  
  final ValueNotifier<double> _directionNotifier = ValueNotifier<double>(0.0);
  StreamSubscription<CompassEvent>? _compassSubscription;
  
  @override
  void initState() {
    super.initState();
    
    _compassSubscription = FlutterCompass.events?.listen((event) {
      if (mounted && event.heading != null) {
        
        _directionNotifier.value = event.heading!;
      }
    });
  }

  @override
  void dispose() {
    _compassSubscription?.cancel();
    _directionNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    
    
    return ValueListenableBuilder<double>(
      valueListenable: _directionNotifier,
      builder: (context, direction, child) {
        return Transform.rotate(
          angle: (direction * (math.pi / 180)),
          child: RepaintBoundary(
            child: CustomPaint(
              painter: _BeamPainter(color: Colors.blueAccent.withOpacity(0.5)),
              child: Center(
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.blueAccent,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      )
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _BeamPainter extends CustomPainter {
  final Color color;

  _BeamPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 1.8; 

    final paint = Paint()
      ..shader = RadialGradient(
        colors: [color, color.withOpacity(0)],
        stops: const [0.0, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    final path = Path();
    path.moveTo(center.dx, center.dy);
    path.arcTo(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2 - (math.pi / 6), 
      math.pi / 3, 
      false,
    );
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
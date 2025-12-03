import 'dart:async';
import 'package:flutter/foundation.dart'; 
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../data/route_repository.dart';
import 'settings_provider.dart';

final repositoryProvider = Provider((ref) => RouteRepository());

final savedRoutesProvider = StreamProvider<List<SavedRoute>>((ref) {
  final repo = ref.watch(repositoryProvider);
  return repo.watchRoutes();
});

class TrackingState {
  final bool isTracking;
  final List<LatLng> currentPath;
  final List<RoutePoint> rawPoints;
  final double totalDistanceMeters;
  final List<Checkpoint> checkpoints;
  final double currentHeading;

  TrackingState({
    this.isTracking = false,
    this.currentPath = const [],
    this.rawPoints = const [],
    this.totalDistanceMeters = 0.0,
    this.checkpoints = const [],
    this.currentHeading = 0.0,
  });

  TrackingState copyWith({
    bool? isTracking,
    List<LatLng>? currentPath,
    List<RoutePoint>? rawPoints,
    double? totalDistanceMeters,
    List<Checkpoint>? checkpoints,
    double? currentHeading,
  }) {
    return TrackingState(
      isTracking: isTracking ?? this.isTracking,
      currentPath: currentPath ?? this.currentPath,
      rawPoints: rawPoints ?? this.rawPoints,
      totalDistanceMeters: totalDistanceMeters ?? this.totalDistanceMeters,
      checkpoints: checkpoints ?? this.checkpoints,
      currentHeading: currentHeading ?? this.currentHeading,
    );
  }
}

final trackingProvider = StateNotifierProvider<TrackingNotifier, TrackingState>((ref) {
  return TrackingNotifier(ref);
});

class TrackingNotifier extends StateNotifier<TrackingState> {
  StreamSubscription<Position>? _positionStream;
  final Ref ref;

  TrackingNotifier(this.ref) : super(TrackingState());

  

  
  
  double _getPerpendicularDistance(RoutePoint p, RoutePoint a, RoutePoint b) {
    final dist = const Distance();
    
    
    final dx = b.longitude - a.longitude;
    final dy = b.latitude - a.latitude;

    if (dx == 0.0 && dy == 0.0) {
      
      return dist.as(LengthUnit.Meter, LatLng(p.latitude, p.longitude), LatLng(a.latitude, a.longitude));
    }

    
    final t = ((p.longitude - a.longitude) * dx + (p.latitude - a.latitude) * dy) / (dx * dx + dy * dy);

    double closestLat;
    double closestLng;

    if (t < 0) {
      
      closestLat = a.latitude;
      closestLng = a.longitude;
    } else if (t > 1) {
      
      closestLat = b.latitude;
      closestLng = b.longitude;
    } else {
      
      closestLat = a.latitude + t * dy;
      closestLng = a.longitude + t * dx;
    }

    
    return dist.as(LengthUnit.Meter, LatLng(p.latitude, p.longitude), LatLng(closestLat, closestLng));
  }
  
  List<RoutePoint> _simplifyRouteRecursive(List<RoutePoint> points, double toleranceMeters) {
    if (points.length < 3) return points;

    double maxDistance = 0;
    int maxIndex = 0;
    final start = points.first;
    final end = points.last;

    
    for (int i = 1; i < points.length - 1; i++) {
        final current = points[i];
        final dist = _getPerpendicularDistance(current, start, end);
        if (dist > maxDistance) {
            maxDistance = dist;
            maxIndex = i;
        }
    }
    
    
    if (maxDistance > toleranceMeters) {
      
      List<RoutePoint> recursiveResults1 = _simplifyRouteRecursive(points.sublist(0, maxIndex + 1), toleranceMeters);
      
      
      List<RoutePoint> recursiveResults2 = _simplifyRouteRecursive(points.sublist(maxIndex, points.length), toleranceMeters);

      
      List<RoutePoint> result = [];
      result.addAll(recursiveResults1.sublist(0, recursiveResults1.length - 1));
      result.addAll(recursiveResults2);

      return result;
    } else {
      
      return [start, end];
    }
  }

  Future<void> startTracking() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    state = state.copyWith(
      isTracking: true, 
      currentPath: [], 
      rawPoints: [], 
      totalDistanceMeters: 0,
      checkpoints: [],
    );

    LocationSettings locationSettings;
    const accuracy = LocationAccuracy.bestForNavigation;
    const distanceFilter = 0; 

    if (defaultTargetPlatform == TargetPlatform.android) {
      locationSettings = AndroidSettings(
        accuracy: accuracy,
        distanceFilter: distanceFilter,
        forceLocationManager: true,
        intervalDuration: const Duration(milliseconds: 500),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: "Route Memory is Active",
          notificationText: "Tracking your journey in background...",
          enableWakeLock: true,
        ),
      );
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      locationSettings = AppleSettings(
        accuracy: accuracy,
        activityType: ActivityType.fitness,
        distanceFilter: distanceFilter,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: true,
      );
    } else {
      locationSettings = const LocationSettings(accuracy: accuracy, distanceFilter: distanceFilter);
    }

    _positionStream = Geolocator.getPositionStream(locationSettings: locationSettings)
        .listen((Position? position) {
      if (position != null) {
        final newLatLong = LatLng(position.latitude, position.longitude);
        double addedDist = 0;
        
        if (state.rawPoints.isNotEmpty) {
          final last = state.rawPoints.last;
          addedDist = Geolocator.distanceBetween(
            last.latitude, last.longitude,
            position.latitude, position.longitude
          );
          
          
          if (addedDist < 1.5) return; 
          
          if (addedDist < 0.5) addedDist = 0;
        }

        final newPoint = RoutePoint(
          latitude: position.latitude, 
          longitude: position.longitude, 
          timestamp: DateTime.now(),
          heading: position.heading,
        );

        state = state.copyWith(
          currentPath: [...state.currentPath, newLatLong],
          rawPoints: [...state.rawPoints, newPoint],
          totalDistanceMeters: state.totalDistanceMeters + addedDist,
          currentHeading: position.heading,
        );
      }
    });
  }

  void addCheckpoint(String name) {
    if (state.rawPoints.isEmpty) return;
    final lastPoint = state.rawPoints.last;
    final checkpoint = Checkpoint(name: name, latitude: lastPoint.latitude, longitude: lastPoint.longitude);
    state = state.copyWith(checkpoints: [...state.checkpoints, checkpoint]);
  }

  Future<void> stopTracking(String routeName) async {
    await _positionStream?.cancel();
    _positionStream = null;

    if (state.rawPoints.isNotEmpty) {
      
      
      final simplifiedPoints = _simplifyRouteRecursive(state.rawPoints, 5.0);
      debugPrint("Route simplified from ${state.rawPoints.length} points to ${simplifiedPoints.length} points.");
      
      final newRoute = SavedRoute(
        id: '', 
        name: routeName.isEmpty ? "Untitled Route" : routeName,
        startTime: state.rawPoints.first.timestamp,
        points: simplifiedPoints, 
        totalDistance: state.totalDistanceMeters,
        checkpoints: List.from(state.checkpoints),
      );
      
      await ref.read(repositoryProvider).addRoute(newRoute);
    }
    state = state.copyWith(isTracking: false);
  }

  Future<void> discardTracking() async {
    await _positionStream?.cancel();
    _positionStream = null;
    state = state.copyWith(isTracking: false, currentPath: [], rawPoints: []);
  }
}
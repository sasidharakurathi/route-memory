import 'dart:async';
import 'package:flutter/foundation.dart'; 
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../data/route_repository.dart';

final savedRoutesProvider = StateNotifierProvider<SavedRoutesNotifier, List<SavedRoute>>((ref) {
  return SavedRoutesNotifier();
});

class SavedRoutesNotifier extends StateNotifier<List<SavedRoute>> {
  SavedRoutesNotifier() : super([]) { _loadRoutes(); }

  Future<void> _loadRoutes() async {
    final box = await Hive.openBox<SavedRoute>('routes');
    state = box.values.toList().reversed.toList();
  }

  Future<void> saveRoute(SavedRoute route) async {
    final box = await Hive.openBox<SavedRoute>('routes');
    await box.add(route);
    state = [route, ...state];
  }

  Future<void> deleteRoute(SavedRoute route) async {
    await route.delete(); 
    _loadRoutes(); 
  }

  Future<void> deleteRoutes(List<SavedRoute> routesToDelete) async {
    for (var route in routesToDelete) {
      await route.delete();
    }
    _loadRoutes();
  }

  Future<void> clearAllRoutes() async {
    final box = await Hive.openBox<SavedRoute>('routes');
    await box.clear();
    state = [];
  }

  Future<void> renameRoute(SavedRoute oldRoute, String newName) async {
    final newRoute = SavedRoute(
      id: oldRoute.id,
      name: newName,
      startTime: oldRoute.startTime,
      points: oldRoute.points,
      totalDistance: oldRoute.totalDistance,
      checkpoints: oldRoute.checkpoints,
    );
    
    final box = await Hive.openBox<SavedRoute>('routes');
    await box.put(oldRoute.key, newRoute);
    _loadRoutes();
  }
}

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
    
    if (defaultTargetPlatform == TargetPlatform.android) {
      locationSettings = AndroidSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 0,
        forceLocationManager: true, 
        intervalDuration: const Duration(seconds: 1),
      );
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      locationSettings = AppleSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        activityType: ActivityType.fitness,
        distanceFilter: 0,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: true,
      );
    } else {
      locationSettings = const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation, 
        distanceFilter: 0
      );
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
      final newRoute = SavedRoute(
        id: DateTime.now().toIso8601String(),
        name: routeName.isEmpty ? "Untitled Route" : routeName,
        startTime: state.rawPoints.first.timestamp,
        points: List.from(state.rawPoints),
        totalDistance: state.totalDistanceMeters,
        checkpoints: List.from(state.checkpoints),
      );
      ref.read(savedRoutesProvider.notifier).saveRoute(newRoute);
    }
    state = state.copyWith(isTracking: false);
  }

  Future<void> discardTracking() async {
    await _positionStream?.cancel();
    _positionStream = null;
    state = state.copyWith(isTracking: false, currentPath: [], rawPoints: []);
  }
}
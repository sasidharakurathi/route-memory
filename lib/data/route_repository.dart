import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RoutePoint {
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final double heading;

  RoutePoint({required this.latitude, required this.longitude, required this.timestamp, this.heading = 0.0});

  Map<String, dynamic> toMap() => {'lat': latitude, 'lng': longitude, 'time': timestamp.millisecondsSinceEpoch, 'head': heading};
  factory RoutePoint.fromMap(Map<String, dynamic> map) => RoutePoint(latitude: map['lat'] ?? 0.0, longitude: map['lng'] ?? 0.0, timestamp: DateTime.fromMillisecondsSinceEpoch(map['time'] ?? 0), heading: (map['head'] ?? 0.0).toDouble());
}

class Checkpoint {
  final String name;
  final double latitude;
  final double longitude;

  Checkpoint({required this.name, required this.latitude, required this.longitude});
  Map<String, dynamic> toMap() => {'n': name, 'lat': latitude, 'lng': longitude};
  factory Checkpoint.fromMap(Map<String, dynamic> map) => Checkpoint(name: map['n'] ?? '', latitude: map['lat'] ?? 0.0, longitude: map['lng'] ?? 0.0);
}

class SavedRoute {
  final String id;
  final String name;
  final DateTime startTime;
  final List<RoutePoint> points;
  final double totalDistance;
  final List<Checkpoint> checkpoints;

  SavedRoute({required this.id, required this.name, required this.startTime, required this.points, this.totalDistance = 0.0, this.checkpoints = const []});

  Duration get duration => points.isNotEmpty ? points.last.timestamp.difference(startTime) : Duration.zero;

  Map<String, dynamic> toMap() => {'id': id, 'name': name, 'startTime': startTime.millisecondsSinceEpoch, 'points': points.map((p) => p.toMap()).toList(), 'dist': totalDistance, 'stops': checkpoints.map((c) => c.toMap()).toList()};
  factory SavedRoute.fromMap(Map<String, dynamic> map, String docId) => SavedRoute(id: docId, name: map['name'] ?? 'Unnamed', startTime: DateTime.fromMillisecondsSinceEpoch(map['startTime'] ?? 0), points: (map['points'] as List<dynamic>? ?? []).map((x) => RoutePoint.fromMap(x)).toList(), totalDistance: (map['dist'] ?? 0.0).toDouble(), checkpoints: (map['stops'] as List<dynamic>? ?? []).map((x) => Checkpoint.fromMap(x)).toList());
}


class SavedLocation {
  final String id;
  final String name;
  final String category;
  final double latitude;
  final double longitude;

  SavedLocation({
    required this.id,
    required this.name,
    required this.category,
    required this.latitude,
    required this.longitude,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'cat': category,
      'lat': latitude,
      'lng': longitude,
      'created': DateTime.now().millisecondsSinceEpoch,
    };
  }

  factory SavedLocation.fromMap(Map<String, dynamic> map, String docId) {
    return SavedLocation(
      id: docId,
      name: map['name'] ?? 'Unknown Place',
      category: map['cat'] ?? 'Uncategorized',
      latitude: map['lat'] ?? 0.0,
      longitude: map['lng'] ?? 0.0,
    );
  }
}

class RouteRepository {
  String get _userId => FirebaseAuth.instance.currentUser?.uid ?? 'guest';

  CollectionReference get _routesRef => FirebaseFirestore.instance.collection('users').doc(_userId).collection('routes');

  CollectionReference get _locationsRef => FirebaseFirestore.instance.collection('users').doc(_userId).collection('locations');

  Stream<List<SavedRoute>> watchRoutes() {
    return _routesRef.orderBy('startTime', descending: true).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => SavedRoute.fromMap(doc.data() as Map<String, dynamic>, doc.id)).toList();
    });
  }
  Future<void> addRoute(SavedRoute route) async => await _routesRef.add(route.toMap());
  Future<void> updateRouteName(String id, String newName) async => await _routesRef.doc(id).update({'name': newName});
  Future<void> deleteRoute(String id) async => await _routesRef.doc(id).delete();
  Future<void> deleteRoutes(List<String> ids) async {
    final batch = FirebaseFirestore.instance.batch();
    for (var id in ids) batch.delete(_routesRef.doc(id));
    await batch.commit();
  }
  Future<void> clearAll() async {
    final snapshot = await _routesRef.get();
    final batch = FirebaseFirestore.instance.batch();
    for (var doc in snapshot.docs) batch.delete(doc.reference);
    await batch.commit();
  }

  Stream<List<SavedLocation>> watchLocations() {
    return _locationsRef.orderBy('created', descending: true).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => SavedLocation.fromMap(doc.data() as Map<String, dynamic>, doc.id)).toList();
    });
  }

  Future<void> addLocation(SavedLocation loc) async {
    await _locationsRef.add(loc.toMap());
  }

  
  
  Future<void> updateLocationName(String id, String newName) async {
    await _locationsRef.doc(id).update({'name': newName});
  }

  Future<void> deleteLocation(String id) async {
    await _locationsRef.doc(id).delete();
  }

  Future<void> deleteLocations(List<String> ids) async {
    final batch = FirebaseFirestore.instance.batch();
    for (var id in ids) batch.delete(_locationsRef.doc(id));
    await batch.commit();
  }

  Future<void> clearAllLocations() async {
    final snapshot = await _locationsRef.get();
    final batch = FirebaseFirestore.instance.batch();
    for (var doc in snapshot.docs) batch.delete(doc.reference);
    await batch.commit();
  }
}
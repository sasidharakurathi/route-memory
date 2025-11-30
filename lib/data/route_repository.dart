import 'package:hive_flutter/hive_flutter.dart';

@HiveType(typeId: 0)
class RoutePoint {
  @HiveField(0)
  final double latitude;
  @HiveField(1)
  final double longitude;
  @HiveField(2)
  final DateTime timestamp;
  @HiveField(3)
  final double heading;

  RoutePoint({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    this.heading = 0.0,
  });
}

@HiveType(typeId: 2)
class Checkpoint {
  @HiveField(0)
  final String name;
  @HiveField(1)
  final double latitude;
  @HiveField(2)
  final double longitude;

  Checkpoint({required this.name, required this.latitude, required this.longitude});
}

@HiveType(typeId: 1)
class SavedRoute extends HiveObject {
  @HiveField(0)
  final String id;
  @HiveField(1)
  final String name;
  @HiveField(2)
  final DateTime startTime;
  @HiveField(3)
  final List<RoutePoint> points;
  @HiveField(4)
  final double totalDistance;
  @HiveField(5)
  final List<Checkpoint> checkpoints;

  SavedRoute({
    required this.id,
    required this.name,
    required this.startTime,
    required this.points,
    this.totalDistance = 0.0,
    this.checkpoints = const [],
  });
}

class RoutePointAdapter extends TypeAdapter<RoutePoint> {
  @override
  final int typeId = 0;
  @override
  RoutePoint read(BinaryReader reader) {
    return RoutePoint(
      latitude: reader.readDouble(),
      longitude: reader.readDouble(),
      timestamp: DateTime.fromMillisecondsSinceEpoch(reader.readInt()),
      heading: reader.readDouble(),
    );
  }
  @override
  void write(BinaryWriter writer, RoutePoint obj) {
    writer.writeDouble(obj.latitude);
    writer.writeDouble(obj.longitude);
    writer.writeInt(obj.timestamp.millisecondsSinceEpoch);
    writer.writeDouble(obj.heading);
  }
}

class CheckpointAdapter extends TypeAdapter<Checkpoint> {
  @override
  final int typeId = 2;
  @override
  Checkpoint read(BinaryReader reader) {
    return Checkpoint(
      name: reader.readString(),
      latitude: reader.readDouble(),
      longitude: reader.readDouble(),
    );
  }
  @override
  void write(BinaryWriter writer, Checkpoint obj) {
    writer.writeString(obj.name);
    writer.writeDouble(obj.latitude);
    writer.writeDouble(obj.longitude);
  }
}

class SavedRouteAdapter extends TypeAdapter<SavedRoute> {
  @override
  final int typeId = 1;
  @override
  SavedRoute read(BinaryReader reader) {
    return SavedRoute(
      id: reader.readString(),
      name: reader.readString(),
      startTime: DateTime.fromMillisecondsSinceEpoch(reader.readInt()),
      points: (reader.readList()).cast<RoutePoint>(),
      totalDistance: reader.readDouble(),
      checkpoints: (reader.readList()).cast<Checkpoint>(),
    );
  }
  @override
  void write(BinaryWriter writer, SavedRoute obj) {
    writer.writeString(obj.id);
    writer.writeString(obj.name);
    writer.writeInt(obj.startTime.millisecondsSinceEpoch);
    writer.writeList(obj.points);
    writer.writeDouble(obj.totalDistance);
    writer.writeList(obj.checkpoints);
  }
}
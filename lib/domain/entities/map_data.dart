import 'package:equatable/equatable.dart';

/// A point in the robot's map coordinate space, in meters, with the origin
/// at the map's saved reference point.
class MapPoint extends Equatable {
  const MapPoint(this.x, this.y);

  final double x;
  final double y;

  MapPoint operator +(MapPoint other) => MapPoint(x + other.x, y + other.y);

  @override
  List<Object?> get props => [x, y];
}

/// Robot (or dock) pose: position plus heading in radians.
class Pose extends Equatable {
  const Pose({required this.position, required this.headingRadians});

  final MapPoint position;
  final double headingRadians;

  @override
  List<Object?> get props => [position, headingRadians];
}

/// A named, closed-polygon room boundary discovered or edited on the map.
class RoomZone extends Equatable {
  const RoomZone({
    required this.id,
    required this.name,
    required this.polygon,
    required this.colorValue,
    required this.floorIndex,
    this.cleaningOrder,
  });

  final String id;
  final String name;
  final List<MapPoint> polygon;

  /// ARGB color value used to fill/tint this room on the map canvas.
  final int colorValue;
  final int floorIndex;
  final int? cleaningOrder;

  RoomZone copyWith({
    String? name,
    List<MapPoint>? polygon,
    int? colorValue,
    int? cleaningOrder,
  }) {
    return RoomZone(
      id: id,
      name: name ?? this.name,
      polygon: polygon ?? this.polygon,
      colorValue: colorValue ?? this.colorValue,
      floorIndex: floorIndex,
      cleaningOrder: cleaningOrder ?? this.cleaningOrder,
    );
  }

  @override
  List<Object?> get props => [id, name, polygon, colorValue, floorIndex, cleaningOrder];
}

enum RestrictedZoneType { virtualWall, noGo, noMop }

/// A user-defined restricted area or wall segment.
class RestrictedZone extends Equatable {
  const RestrictedZone({
    required this.id,
    required this.type,
    required this.points,
  });

  final String id;
  final RestrictedZoneType type;

  /// Two points for a [RestrictedZoneType.virtualWall] line; four+ points
  /// forming a closed polygon for no-go/no-mop areas.
  final List<MapPoint> points;

  @override
  List<Object?> get props => [id, type, points];
}

enum FurnitureKind { sofa, bed, table, cabinet, other }

class FurnitureMarker extends Equatable {
  const FurnitureMarker({
    required this.id,
    required this.kind,
    required this.position,
    required this.rotationRadians,
  });

  final String id;
  final FurnitureKind kind;
  final MapPoint position;
  final double rotationRadians;

  @override
  List<Object?> get props => [id, kind, position, rotationRadians];
}

class CarpetArea extends Equatable {
  const CarpetArea({required this.id, required this.polygon});

  final String id;
  final List<MapPoint> polygon;

  @override
  List<Object?> get props => [id, polygon];
}

/// One saved SLAM map, scoped to a single floor of a multi-floor home.
class CleaningMap extends Equatable {
  const CleaningMap({
    required this.id,
    required this.name,
    required this.floorIndex,
    required this.robotPose,
    required this.dockPose,
    required this.path,
    required this.rooms,
    required this.restrictedZones,
    required this.furniture,
    required this.carpetAreas,
    required this.updatedAt,
  });

  factory CleaningMap.empty(String id) {
    return CleaningMap(
      id: id,
      name: 'Home',
      floorIndex: 0,
      robotPose: const Pose(position: MapPoint(0, 0), headingRadians: 0),
      dockPose: const Pose(position: MapPoint(0, 0), headingRadians: 0),
      path: const [],
      rooms: const [],
      restrictedZones: const [],
      furniture: const [],
      carpetAreas: const [],
      updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  final String id;
  final String name;
  final int floorIndex;
  final Pose robotPose;
  final Pose dockPose;
  final List<MapPoint> path;
  final List<RoomZone> rooms;
  final List<RestrictedZone> restrictedZones;
  final List<FurnitureMarker> furniture;
  final List<CarpetArea> carpetAreas;
  final DateTime updatedAt;

  CleaningMap copyWith({
    String? name,
    Pose? robotPose,
    Pose? dockPose,
    List<MapPoint>? path,
    List<RoomZone>? rooms,
    List<RestrictedZone>? restrictedZones,
    List<FurnitureMarker>? furniture,
    List<CarpetArea>? carpetAreas,
    DateTime? updatedAt,
  }) {
    return CleaningMap(
      id: id,
      name: name ?? this.name,
      floorIndex: floorIndex,
      robotPose: robotPose ?? this.robotPose,
      dockPose: dockPose ?? this.dockPose,
      path: path ?? this.path,
      rooms: rooms ?? this.rooms,
      restrictedZones: restrictedZones ?? this.restrictedZones,
      furniture: furniture ?? this.furniture,
      carpetAreas: carpetAreas ?? this.carpetAreas,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        floorIndex,
        robotPose,
        dockPose,
        path,
        rooms,
        restrictedZones,
        furniture,
        carpetAreas,
        updatedAt,
      ];
}

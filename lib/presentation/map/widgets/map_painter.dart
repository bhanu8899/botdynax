import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../domain/entities/map_data.dart';

/// Meters-to-pixels scale used across the map canvas. A larger value zooms
/// the "native" (1.0x InteractiveViewer scale) rendering in.
const double kPixelsPerMeter = 80;

/// Renders the full SLAM map — rooms, zones, furniture, carpet, cleaning
/// path, dock, and the live robot marker — onto a canvas sized in meters
/// and scaled by [kPixelsPerMeter].
class MapPainter extends CustomPainter {
  const MapPainter({
    required this.map,
    required this.animatedRobotPose,
    required this.selectedRoomId,
    required this.origin,
  });

  final CleaningMap map;
  final Pose animatedRobotPose;
  final String? selectedRoomId;

  /// Top-left of the canvas in map-meters space (so maps that don't start
  /// at (0,0) still render fully on-canvas).
  final MapPoint origin;

  Offset _toCanvas(MapPoint p) {
    return _mapPointToCanvas(p, origin);
  }

  /// Finds the room (if any) whose polygon contains [localPosition] — a tap
  /// position in the same untransformed canvas-pixel space this painter
  /// draws in (i.e. straight from a `GestureDetector` on the painted
  /// widget, unaffected by any ancestor `InteractiveViewer` zoom/pan).
  static RoomZone? hitTestRoom(CleaningMap map, MapPoint origin, Offset localPosition) {
    for (final RoomZone room in map.rooms) {
      final Path path = Path();
      final Offset first = _mapPointToCanvas(room.polygon.first, origin);
      path.moveTo(first.dx, first.dy);
      for (final MapPoint p in room.polygon.skip(1)) {
        final Offset o = _mapPointToCanvas(p, origin);
        path.lineTo(o.dx, o.dy);
      }
      path.close();
      if (path.contains(localPosition)) return room;
    }
    return null;
  }

  static Offset _mapPointToCanvas(MapPoint p, MapPoint origin) {
    return Offset((p.x - origin.x) * kPixelsPerMeter, (p.y - origin.y) * kPixelsPerMeter);
  }

  @override
  void paint(Canvas canvas, Size size) {
    _paintBackground(canvas, size);
    _paintCarpets(canvas);
    _paintRooms(canvas);
    _paintRestrictedZones(canvas);
    _paintFurniture(canvas);
    _paintPath(canvas);
    _paintDock(canvas);
    _paintRobot(canvas);
  }

  void _paintBackground(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = AppColors.darkBg);

    final Paint gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.03)
      ..strokeWidth = 1;
    const double step = kPixelsPerMeter / 2;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
  }

  void _paintCarpets(Canvas canvas) {
    final Paint paint = Paint()..color = AppColors.warning.withValues(alpha: 0.08);
    for (final CarpetArea carpet in map.carpetAreas) {
      canvas.drawPath(_polygonPath(carpet.polygon), paint);
    }
  }

  void _paintRooms(Canvas canvas) {
    for (final RoomZone room in map.rooms) {
      final bool selected = room.id == selectedRoomId;
      final Color roomColor = Color(room.colorValue);
      final Path path = _polygonPath(room.polygon);

      canvas.drawPath(path, Paint()..color = roomColor.withValues(alpha: selected ? 0.28 : 0.14));
      canvas.drawPath(
        path,
        Paint()
          ..color = roomColor.withValues(alpha: selected ? 0.9 : 0.45)
          ..style = PaintingStyle.stroke
          ..strokeWidth = selected ? 2.5 : 1.5,
      );

      final Offset centroid = _centroid(room.polygon);
      final TextPainter labelPainter = TextPainter(
        text: TextSpan(
          text: room.name,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.92),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      labelPainter.paint(canvas, centroid - Offset(labelPainter.width / 2, labelPainter.height / 2));
    }
  }

  void _paintRestrictedZones(Canvas canvas) {
    for (final RestrictedZone zone in map.restrictedZones) {
      switch (zone.type) {
        case RestrictedZoneType.virtualWall:
          if (zone.points.length < 2) continue;
          final Paint wallPaint = Paint()
            ..color = AppColors.danger
            ..strokeWidth = 4
            ..strokeCap = StrokeCap.round;
          _drawDashedLine(canvas, _toCanvas(zone.points[0]), _toCanvas(zone.points[1]), wallPaint);
        case RestrictedZoneType.noGo:
          _paintHatchedZone(canvas, zone.points, AppColors.danger);
        case RestrictedZoneType.noMop:
          _paintHatchedZone(canvas, zone.points, AppColors.neonBlue);
      }
    }
  }

  void _paintHatchedZone(Canvas canvas, List<MapPoint> points, Color color) {
    if (points.length < 3) return;
    final Path path = _polygonPath(points);

    canvas.save();
    canvas.clipPath(path);
    canvas.drawPath(path, Paint()..color = color.withValues(alpha: 0.12));

    final Rect bounds = path.getBounds();
    final Paint hatchPaint = Paint()
      ..color = color.withValues(alpha: 0.5)
      ..strokeWidth = 1.5;
    const double gap = 10;
    for (double x = bounds.left - bounds.height; x < bounds.right; x += gap) {
      canvas.drawLine(Offset(x, bounds.bottom), Offset(x + bounds.height, bounds.top), hatchPaint);
    }
    canvas.restore();

    canvas.drawPath(
      path,
      Paint()
        ..color = color.withValues(alpha: 0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  void _paintFurniture(Canvas canvas) {
    for (final FurnitureMarker item in map.furniture) {
      final Offset center = _toCanvas(item.position);
      final IconData icon = switch (item.kind) {
        FurnitureKind.sofa => Icons.weekend_rounded,
        FurnitureKind.bed => Icons.bed_rounded,
        FurnitureKind.table => Icons.table_restaurant_rounded,
        FurnitureKind.cabinet => Icons.kitchen_rounded,
        FurnitureKind.other => Icons.square_rounded,
      };

      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(item.rotationRadians);

      final TextPainter iconPainter = TextPainter(
        text: TextSpan(
          text: String.fromCharCode(icon.codePoint),
          style: TextStyle(
            fontSize: 20,
            fontFamily: icon.fontFamily,
            package: icon.fontPackage,
            color: Colors.white.withValues(alpha: 0.35),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      iconPainter.paint(canvas, Offset(-iconPainter.width / 2, -iconPainter.height / 2));
      canvas.restore();
    }
  }

  void _paintPath(Canvas canvas) {
    if (map.path.length < 2) return;
    final int total = map.path.length;

    for (int i = 1; i < total; i++) {
      final double age = i / total;
      final Paint segmentPaint = Paint()
        ..color = AppColors.neonCyan.withValues(alpha: 0.08 + age * 0.35)
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(_toCanvas(map.path[i - 1]), _toCanvas(map.path[i]), segmentPaint);
    }
  }

  void _paintDock(Canvas canvas) {
    final Offset center = _toCanvas(map.dockPose.position);
    final Paint fill = Paint()..color = AppColors.neonViolet.withValues(alpha: 0.9);
    final Paint glow = Paint()
      ..color = AppColors.neonViolet.withValues(alpha: 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    canvas.drawCircle(center, 14, glow);
    final Path dockShape = Path()
      ..moveTo(center.dx - 10, center.dy + 8)
      ..lineTo(center.dx + 10, center.dy + 8)
      ..lineTo(center.dx + 7, center.dy - 8)
      ..lineTo(center.dx - 7, center.dy - 8)
      ..close();
    canvas.drawPath(dockShape, fill);

    final TextPainter iconPainter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(Icons.bolt_rounded.codePoint),
        style: TextStyle(fontSize: 12, fontFamily: Icons.bolt_rounded.fontFamily, color: Colors.white),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    iconPainter.paint(canvas, center - Offset(iconPainter.width / 2, iconPainter.height / 2));
  }

  void _paintRobot(Canvas canvas) {
    final Offset center = _toCanvas(animatedRobotPose.position);

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(animatedRobotPose.headingRadians);

    canvas.drawCircle(
      Offset.zero,
      20,
      Paint()
        ..color = AppColors.neonCyan.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
    canvas.drawCircle(Offset.zero, 11, Paint()..color = const Color(0xFF1B2130));
    canvas.drawCircle(
      Offset.zero,
      11,
      Paint()
        ..color = AppColors.neonCyan
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    // Heading chevron.
    final Path chevron = Path()
      ..moveTo(11, 0)
      ..lineTo(3, -5)
      ..lineTo(3, 5)
      ..close();
    canvas.drawPath(chevron, Paint()..color = AppColors.neonCyan);

    canvas.restore();
  }

  Path _polygonPath(List<MapPoint> points) {
    final Path path = Path();
    if (points.isEmpty) return path;
    final Offset first = _toCanvas(points.first);
    path.moveTo(first.dx, first.dy);
    for (final MapPoint p in points.skip(1)) {
      final Offset o = _toCanvas(p);
      path.lineTo(o.dx, o.dy);
    }
    path.close();
    return path;
  }

  Offset _centroid(List<MapPoint> points) {
    if (points.isEmpty) return Offset.zero;
    double sumX = 0;
    double sumY = 0;
    for (final MapPoint p in points) {
      final Offset o = _toCanvas(p);
      sumX += o.dx;
      sumY += o.dy;
    }
    return Offset(sumX / points.length, sumY / points.length);
  }

  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    const double dashLength = 8;
    const double gapLength = 6;
    final double totalLength = (end - start).distance;
    if (totalLength == 0) return;
    final Offset direction = (end - start) / totalLength;

    double covered = 0;
    while (covered < totalLength) {
      final double segmentEnd = math.min(covered + dashLength, totalLength);
      canvas.drawLine(start + direction * covered, start + direction * segmentEnd, paint);
      covered += dashLength + gapLength;
    }
  }

  @override
  bool shouldRepaint(covariant MapPainter oldDelegate) {
    return oldDelegate.map != map ||
        oldDelegate.animatedRobotPose != animatedRobotPose ||
        oldDelegate.selectedRoomId != selectedRoomId;
  }
}

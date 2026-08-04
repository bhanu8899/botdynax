import 'dart:async';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../domain/entities/robot_enums.dart';
import '../../domain/entities/robot_status.dart';
import '../providers/auth_providers.dart';
import '../providers/cloud_providers.dart';
import '../providers/robot_providers.dart';

/// Renders the robot's map plus its live traveled path, pulled from Tuya's
/// Sweeping Robot Open Service (`GET /tuya/robots/:robotId/map`, proxied by
/// the backend — see `TuyaService.getLatestMap`).
///
/// Deliberately separate from [MapScreen]/[MapPainter]: those render the
/// simulator's vector format (room polygons, virtual walls, furniture) that
/// this device's Cloud API doesn't provide. Tuya gives a point-cloud grid
/// snapshot plus an encoded trajectory blob, which the backend decodes into
/// real grid-space path points, current robot position, and a derived
/// heading.
final FutureProviderFamily<Map<String, dynamic>, String> tuyaMapProvider =
    FutureProvider.family<Map<String, dynamic>, String>((Ref ref, String robotId) async {
  final Dio dio = ref.watch(apiClientProvider).dio;
  final Response<Map<String, dynamic>> response =
      await dio.get<Map<String, dynamic>>('/tuya/robots/$robotId/map');
  return response.data!;
});

class TuyaMapScreen extends ConsumerWidget {
  const TuyaMapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<String?> robotIdAsync = ref.watch(backendRobotIdProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Map'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              final String? robotId = robotIdAsync.valueOrNull;
              if (robotId != null) ref.invalidate(tuyaMapProvider(robotId));
            },
          ),
        ],
      ),
      body: robotIdAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace _) => Center(child: Text('Unable to sync robot.\n$error')),
        data: (String? robotId) {
          if (robotId == null) {
            return const Center(child: Text('Connect a robot first.'));
          }
          return _MapBody(robotId: robotId);
        },
      ),
    );
  }
}

class _MapBody extends ConsumerStatefulWidget {
  const _MapBody({required this.robotId});

  final String robotId;

  @override
  ConsumerState<_MapBody> createState() => _MapBodyState();
}

class _MapBodyState extends ConsumerState<_MapBody> {
  Timer? _refreshTimer;

  /// Tuya publishes a fresh map snapshot periodically while the robot is
  /// cleaning (the trajectory grows between snapshots), so re-fetching on
  /// an interval is what makes the map live. Only polls while the robot is
  /// actually cleaning — a docked robot's map never changes, and this is a
  /// multi-request round trip (list → download link → S3 fetch) on the
  /// backend, so idle polling would be pure waste.
  static const Duration _refreshInterval = Duration(seconds: 12);

  @override
  void initState() {
    super.initState();
    _refreshTimer = Timer.periodic(_refreshInterval, (_) {
      final RobotStatus? status = ref.read(robotStatusProvider).valueOrNull;
      final bool isMoving = status != null &&
          (status.activity == ActivityState.cleaning || status.activity == ActivityState.returningToDock);
      if (isMoving && mounted) {
        ref.invalidate(tuyaMapProvider(widget.robotId));
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<Map<String, dynamic>> mapAsync = ref.watch(tuyaMapProvider(widget.robotId));
    final RobotStatus? status = ref.watch(robotStatusProvider).valueOrNull;

    return mapAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (Object error, StackTrace _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.map_outlined, size: 48, color: Colors.white38),
              const SizedBox(height: 12),
              Text(
                'No map available yet.\n$error',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
      ),
      data: (Map<String, dynamic> map) {
        final Map<String, dynamic>? mapData = map['mapData'] as Map<String, dynamic>?;
        if (mapData == null) {
          return const Center(child: Text('Map response had no data.'));
        }
        final RobotPath path = RobotPath.fromJson(map['path'] as Map<String, dynamic>?);
        final bool isCleaning = status?.activity == ActivityState.cleaning;

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF050708),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: InteractiveViewer(
                      maxScale: 5,
                      child: CustomPaint(
                        painter: TuyaMapPainter(mapData: mapData, path: path),
                        child: const SizedBox.expand(),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _MapLegend(path: path, mapData: mapData, isLive: isCleaning),
            ],
          ),
        );
      },
    );
  }
}

class _MapLegend extends StatelessWidget {
  const _MapLegend({required this.path, required this.mapData, required this.isLive});

  final RobotPath path;
  final Map<String, dynamic> mapData;
  final bool isLive;

  @override
  Widget build(BuildContext context) {
    final List<dynamic> size = mapData['size'] as List<dynamic>;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isLive) ...[
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(color: AppColors.neonCyan, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              const Text('Live', style: TextStyle(color: AppColors.neonCyan, fontSize: 12)),
              const SizedBox(width: 12),
            ],
            Text(
              '${path.points.length} path points',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '${size.join('×')} cells @ ${mapData['resolution']}cm',
          style: const TextStyle(color: Colors.white38, fontSize: 11),
        ),
      ],
    );
  }
}

/// The robot's decoded trajectory, current position and derived heading,
/// exactly as the backend's `tuya-map-decoder` produced them — all in the
/// same grid-cell space as the map's obstacle/room/charger coordinates.
class RobotPath {
  const RobotPath({required this.points, required this.position, required this.headingRadians});

  final List<Offset> points;
  final Offset? position;
  final double? headingRadians;

  static RobotPath fromJson(Map<String, dynamic>? json) {
    if (json == null) return const RobotPath(points: [], position: null, headingRadians: null);

    final List<dynamic> rawPoints = json['points'] as List<dynamic>? ?? const [];
    final List<Offset> points = rawPoints
        .map((dynamic p) => Offset(
              ((p as Map<String, dynamic>)['x'] as num).toDouble(),
              (p['y'] as num).toDouble(),
            ))
        .toList();

    final Map<String, dynamic>? rawPos = json['robotPosition'] as Map<String, dynamic>?;
    final Offset? position =
        rawPos == null ? null : Offset((rawPos['x'] as num).toDouble(), (rawPos['y'] as num).toDouble());

    final num? heading = json['headingRadians'] as num?;

    return RobotPath(points: points, position: position, headingRadians: heading?.toDouble());
  }
}

/// Draws Tuya's point-cloud map (room floor cells, obstacle/wall cells,
/// charging dock) plus the robot's real traveled path and current pose.
/// Coordinates throughout are grid cells — see `mapData.resolution` for
/// centimetres per cell.
class TuyaMapPainter extends CustomPainter {
  TuyaMapPainter({required this.mapData, required this.path});

  final Map<String, dynamic> mapData;
  final RobotPath path;

  @override
  void paint(Canvas canvas, Size size) {
    final List<dynamic> sizeArr = mapData['size'] as List<dynamic>;
    final int gridW = sizeArr[0] as int;
    final int gridH = sizeArr[1] as int;
    if (gridW == 0 || gridH == 0) return;

    final double scale =
        (size.width / gridW < size.height / gridH) ? size.width / gridW : size.height / gridH;
    final double offsetX = (size.width - gridW * scale) / 2;
    final double offsetY = (size.height - gridH * scale) / 2;

    Offset toCanvas(double gx, double gy) => Offset(offsetX + gx * scale, offsetY + gy * scale);

    void paintPoints(List<dynamic> coords, Paint paint) {
      for (int i = 0; i + 1 < coords.length; i += 2) {
        final double x = (coords[i] as num).toDouble();
        final double y = (coords[i + 1] as num).toDouble();
        canvas.drawRect(
          Rect.fromLTWH(offsetX + x * scale, offsetY + y * scale, scale + 0.5, scale + 0.5),
          paint,
        );
      }
    }

    // Room floor.
    final Paint roomPaint = Paint()..color = const Color(0xFF1C3A3A);
    if (mapData['rooms'] is Map) {
      for (final dynamic room in (mapData['rooms'] as Map<dynamic, dynamic>).values) {
        paintPoints((room as Map<String, dynamic>)['coordinates'] as List<dynamic>? ?? const [], roomPaint);
      }
    }

    // Walls / obstacles.
    final Paint obstaclePaint = Paint()..color = AppColors.neonCyan;
    for (final dynamic group in mapData['obstacles'] as List<dynamic>? ?? const []) {
      paintPoints((group as Map<String, dynamic>)['coordinates'] as List<dynamic>? ?? const [], obstaclePaint);
    }

    // Traveled path.
    if (path.points.length > 1) {
      final Path trail = Path();
      final Offset first = toCanvas(path.points.first.dx, path.points.first.dy);
      trail.moveTo(first.dx, first.dy);
      for (final Offset p in path.points.skip(1)) {
        final Offset c = toCanvas(p.dx, p.dy);
        trail.lineTo(c.dx, c.dy);
      }
      canvas.drawPath(
        trail,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1.2, scale * 0.45)
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = AppColors.neonViolet.withValues(alpha: 0.75),
      );
    }

    // Charging dock.
    final Map<String, dynamic>? charger = mapData['charger'] as Map<String, dynamic>?;
    if (charger != null) {
      final List<dynamic> coordinate = charger['coordinate'] as List<dynamic>;
      final Offset c = toCanvas((coordinate[0] as num).toDouble(), (coordinate[1] as num).toDouble());
      canvas.drawCircle(c, math.max(4, scale * 1.2), Paint()..color = AppColors.neonBlue);
      canvas.drawCircle(
        c,
        math.max(7, scale * 2.0),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = AppColors.neonBlue.withValues(alpha: 0.5),
      );
    }

    // Robot, oriented along its derived heading.
    final Offset? pos = path.position;
    if (pos != null) {
      final Offset c = toCanvas(pos.dx, pos.dy);
      final double r = math.max(6, scale * 1.6);

      canvas.drawCircle(
        c,
        r * 1.9,
        Paint()
          ..shader = RadialGradient(
            colors: [
              AppColors.neonCyan.withValues(alpha: 0.35),
              AppColors.neonCyan.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromCircle(center: c, radius: r * 1.9)),
      );
      canvas.drawCircle(c, r, Paint()..color = AppColors.neonCyan);
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = Colors.white.withValues(alpha: 0.85),
      );

      final double? heading = path.headingRadians;
      if (heading != null) {
        canvas.save();
        canvas.translate(c.dx, c.dy);
        canvas.rotate(heading);
        final Path arrow = Path()
          ..moveTo(r * 1.75, 0)
          ..lineTo(r * 0.55, -r * 0.7)
          ..lineTo(r * 0.55, r * 0.7)
          ..close();
        canvas.drawPath(arrow, Paint()..color = Colors.white);
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(covariant TuyaMapPainter oldDelegate) =>
      oldDelegate.mapData != mapData || oldDelegate.path != path;
}

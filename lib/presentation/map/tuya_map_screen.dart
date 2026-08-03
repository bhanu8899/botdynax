import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../providers/auth_providers.dart';
import '../providers/cloud_providers.dart';

/// Renders the robot's last saved map snapshot pulled from Tuya's Sweeping
/// Robot Open Service (`GET /tuya/robots/:robotId/map`, proxied by the
/// backend — see `TuyaService.getLatestMap`). Deliberately separate from
/// [MapScreen]/[MapPainter]: those render the simulator's richer vector
/// format (room polygons, virtual walls, furniture) that this device's
/// Cloud API doesn't provide. Tuya only gives a point-cloud grid snapshot
/// (walls/floor plotted as individual cells, not polygons) — this screen
/// is honest about that shape rather than forcing it into the other model.
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
        title: const Text('SLAM Map'),
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

class _MapBody extends ConsumerWidget {
  const _MapBody({required this.robotId});

  final String robotId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<Map<String, dynamic>> mapAsync = ref.watch(tuyaMapProvider(robotId));

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
                  child: CustomPaint(
                    painter: TuyaMapPainter(mapData),
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '${(mapData['size'] as List<dynamic>).join('×')} cells @ ${mapData['resolution']}cm/cell',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Draws Tuya's point-cloud map: room floor cells, obstacle/wall cells, and
/// the charging dock. Coordinates are grid cells (not real-world units) —
/// see `mapData.resolution` (cm per cell) for the real-world scale.
class TuyaMapPainter extends CustomPainter {
  TuyaMapPainter(this.mapData);

  final Map<String, dynamic> mapData;

  @override
  void paint(Canvas canvas, Size size) {
    final List<dynamic> sizeArr = mapData['size'] as List<dynamic>;
    final int gridW = sizeArr[0] as int;
    final int gridH = sizeArr[1] as int;
    if (gridW == 0 || gridH == 0) return;

    final double scale = (size.width / gridW < size.height / gridH)
        ? size.width / gridW
        : size.height / gridH;
    final double offsetX = (size.width - gridW * scale) / 2;
    final double offsetY = (size.height - gridH * scale) / 2;

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

    final Paint roomPaint = Paint()..color = const Color(0xFF1C3A3A);
    final List<dynamic>? rooms = mapData['rooms'] is Map ? (mapData['rooms'] as Map).values.toList() : null;
    if (rooms != null) {
      for (final dynamic room in rooms) {
        final List<dynamic> coords = (room as Map<String, dynamic>)['coordinates'] as List<dynamic>? ?? [];
        paintPoints(coords, roomPaint);
      }
    }

    final Paint obstaclePaint = Paint()..color = AppColors.neonCyan;
    final List<dynamic> obstacles = mapData['obstacles'] as List<dynamic>? ?? [];
    for (final dynamic group in obstacles) {
      final List<dynamic> coords = (group as Map<String, dynamic>)['coordinates'] as List<dynamic>? ?? [];
      paintPoints(coords, obstaclePaint);
    }

    final Map<String, dynamic>? charger = mapData['charger'] as Map<String, dynamic>?;
    if (charger != null) {
      final List<dynamic> coordinate = charger['coordinate'] as List<dynamic>;
      final double cx = offsetX + (coordinate[0] as num).toDouble() * scale;
      final double cy = offsetY + (coordinate[1] as num).toDouble() * scale;
      canvas.drawCircle(Offset(cx, cy), scale.clamp(3.0, 12.0), Paint()..color = const Color(0xFF5B8CFF));
    }
  }

  @override
  bool shouldRepaint(covariant TuyaMapPainter oldDelegate) => oldDelegate.mapData != mapData;
}

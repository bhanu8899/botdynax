import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/widgets/bd_buttons.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/skeleton_loader.dart';
import '../../domain/entities/map_data.dart';
import '../../domain/entities/robot_status.dart';
import '../providers/robot_providers.dart';
import 'pose_tween.dart';
import 'widgets/bottom_control_panel.dart';
import 'widgets/map_painter.dart';

class MapScreen extends ConsumerWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<CleaningMap> mapAsync = ref.watch(robotMapProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Map'),
        leading: const Hero(
          tag: 'live-map-icon',
          child: Icon(Icons.map_rounded),
        ),
      ),
      body: mapAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(AppSpacing.md),
          child: SkeletonBox(width: double.infinity, height: double.infinity, borderRadius: AppRadii.lg),
        ),
        error: (Object error, StackTrace _) => Center(child: Text('Unable to load map.\n$error')),
        data: (CleaningMap map) => _MapView(map: map),
      ),
    );
  }
}

class _MapView extends ConsumerStatefulWidget {
  const _MapView({required this.map});

  final CleaningMap map;

  @override
  ConsumerState<_MapView> createState() => _MapViewState();
}

class _MapViewState extends ConsumerState<_MapView> with SingleTickerProviderStateMixin {
  late final AnimationController _poseController;
  late PoseTween _poseTween;
  late Pose _displayedPose;

  final TransformationController _transformationController = TransformationController();
  int _rotationQuarterTurns = 0;
  String? _selectedRoomId;

  @override
  void initState() {
    super.initState();
    _displayedPose = widget.map.robotPose;
    _poseTween = PoseTween(begin: _displayedPose, end: _displayedPose);
    _poseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
  }

  @override
  void didUpdateWidget(covariant _MapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.map.robotPose != widget.map.robotPose) {
      _poseTween = PoseTween(begin: _displayedPose, end: widget.map.robotPose);
      _poseController
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _poseController.dispose();
    _transformationController.dispose();
    super.dispose();
  }

  ({MapPoint origin, Size size}) _computeBounds(CleaningMap map) {
    double minX = 0;
    double minY = 0;
    double maxX = 6;
    double maxY = 6;

    void expand(MapPoint p) {
      minX = math.min(minX, p.x);
      minY = math.min(minY, p.y);
      maxX = math.max(maxX, p.x);
      maxY = math.max(maxY, p.y);
    }

    for (final RoomZone room in map.rooms) {
      room.polygon.forEach(expand);
    }
    for (final MapPoint p in map.path) {
      expand(p);
    }
    expand(map.dockPose.position);
    expand(map.robotPose.position);

    const double padding = 1.5;
    final MapPoint origin = MapPoint(minX - padding, minY - padding);
    final Size size = Size((maxX - minX + padding * 2) * kPixelsPerMeter, (maxY - minY + padding * 2) * kPixelsPerMeter);
    return (origin: origin, size: size);
  }

  void _handleTapUp(TapUpDetails details, MapPoint origin) {
    final RoomZone? room = MapPainter.hitTestRoom(widget.map, origin, details.localPosition);
    setState(() => _selectedRoomId = room?.id);
    if (room != null) {
      _showRoomSheet(room);
    }
  }

  void _showRoomSheet(RoomZone room) {
    final RobotController controller = ref.read(robotControllerProvider);
    showModalBottomSheet<void>(
      context: context,
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(room.name, style: Theme.of(sheetContext).textTheme.headlineSmall),
                const SizedBox(height: AppSpacing.md),
                BdPrimaryButton(
                  label: 'Clean This Room',
                  icon: Icons.play_arrow_rounded,
                  onPressed: () {
                    Navigator.of(sheetContext).pop();
                    unawaited(controller.roomClean([room.id]));
                  },
                ),
                const SizedBox(height: AppSpacing.sm),
                BdSecondaryButton(
                  label: 'Rename Room',
                  icon: Icons.edit_rounded,
                  onPressed: () {
                    Navigator.of(sheetContext).pop();
                    _promptRename(room);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _promptRename(RoomZone room) async {
    final TextEditingController textController = TextEditingController(text: room.name);
    final String? newName = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Rename Room'),
          content: TextField(controller: textController, autofocus: true),
          actions: [
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cancel')),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(textController.text.trim()),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
    if (newName != null && newName.isNotEmpty) {
      await ref.read(robotControllerProvider).renameRoom(roomId: room.id, name: newName);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ({MapPoint origin, Size size}) bounds = _computeBounds(widget.map);

    return Stack(
      children: [
        InteractiveViewer(
          transformationController: _transformationController,
          minScale: 0.4,
          maxScale: 4,
          boundaryMargin: const EdgeInsets.all(200),
          child: RotatedBox(
            quarterTurns: _rotationQuarterTurns,
            child: GestureDetector(
              onTapUp: (TapUpDetails details) => _handleTapUp(details, bounds.origin),
              child: AnimatedBuilder(
                animation: _poseController,
                builder: (BuildContext context, Widget? _) {
                  _displayedPose = _poseTween.lerp(Curves.easeInOut.transform(_poseController.value));
                  return CustomPaint(
                    size: bounds.size,
                    painter: MapPainter(
                      map: widget.map,
                      animatedRobotPose: _displayedPose,
                      selectedRoomId: _selectedRoomId,
                      origin: bounds.origin,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        Positioned(
          right: AppSpacing.md,
          bottom: 200,
          child: GlassCard(
            padding: const EdgeInsets.all(AppSpacing.xs),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(icon: const Icon(Icons.add), onPressed: () => _zoom(1.25)),
                IconButton(icon: const Icon(Icons.remove), onPressed: () => _zoom(0.8)),
                IconButton(
                  icon: const Icon(Icons.rotate_90_degrees_ccw_rounded),
                  onPressed: () => setState(() => _rotationQuarterTurns = (_rotationQuarterTurns + 1) % 4),
                ),
                IconButton(
                  icon: const Icon(Icons.center_focus_strong_rounded),
                  onPressed: () => _transformationController.value = Matrix4.identity(),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          left: AppSpacing.md,
          right: AppSpacing.md,
          bottom: AppSpacing.md,
          child: Consumer(
            builder: (BuildContext context, WidgetRef ref, Widget? _) {
              final AsyncValue<RobotStatus> statusAsync = ref.watch(robotStatusProvider);
              final RobotStatus? status = statusAsync.valueOrNull;
              if (status == null) return const SizedBox.shrink();
              return BottomControlPanel(
                status: status,
                controller: ref.read(robotControllerProvider),
                selectedRoomId: _selectedRoomId,
              );
            },
          ),
        ),
      ],
    );
  }

  void _zoom(double factor) {
    final Matrix4 matrix = _transformationController.value.clone()..scaleByDouble(factor, factor, factor, 1);
    _transformationController.value = matrix;
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/routing/app_routes.dart';
import '../../core/storage/local_storage_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/animated_progress_ring.dart';
import '../../core/widgets/bd_buttons.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/skeleton_loader.dart';
import '../../core/widgets/status_pill.dart';
import '../../domain/entities/consumable.dart';
import '../../domain/entities/robot_enums.dart';
import '../../domain/entities/robot_status.dart';
import '../../domain/transport/robot_transport.dart';
import '../providers/robot_providers.dart';
import 'widgets/consumable_tile.dart';
import 'widgets/robot_illustration.dart';
import 'widgets/signal_indicator.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((Duration _) {
      unawaited(_pairRobot());
    });
  }

  Future<void> _pairRobot() async {
    try {
      await ref.read(robotControllerProvider).pairDefaultRobot();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not connect to your robot: $error')),
      );
    }
  }

  void _showEventBanner(RobotEvent event) {
    // Errors always surface — Do Not Disturb suppresses routine
    // notifications, not the robot being stuck or broken.
    final bool isError = event is RobotErrorEvent;
    if (!isError && ref.read(localStorageServiceProvider).isWithinDndWindow) return;

    final String message = switch (event) {
      CleaningStartedEvent() => 'Cleaning started',
      CleaningCompletedEvent(:final areaCleanedSqm, :final duration) =>
        'Cleaning completed — ${areaCleanedSqm.toStringAsFixed(1)} m² in ${duration.inMinutes}m',
      RobotErrorEvent(:final code) => 'Robot needs attention: $code',
      FirmwareUpdateAvailableEvent(:final version) => 'Firmware $version is available',
    };

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<RobotStatus> statusAsync = ref.watch(robotStatusProvider);

    ref.listen(robotEventsProvider, (AsyncValue<RobotEvent>? previous, AsyncValue<RobotEvent> next) {
      final RobotEvent? event = next.valueOrNull;
      if (event != null) _showEventBanner(event);
    });

    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none_rounded),
            onPressed: () => context.push(AppRoutes.notifications),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push(AppRoutes.settings),
          ),
        ],
      ),
      body: SafeArea(
        child: statusAsync.when(
          loading: () => const _ConnectingView(),
          error: (Object error, StackTrace stackTrace) => _ErrorView(message: '$error'),
          data: (RobotStatus status) => _DashboardView(status: status),
        ),
      ),
    );
  }
}

class _ConnectingView extends StatelessWidget {
  const _ConnectingView();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      physics: const NeverScrollableScrollPhysics(),
      children: [
        const Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonBox(width: 80, height: 12),
                  SizedBox(height: AppSpacing.xs),
                  SkeletonBox(width: 160, height: 28),
                ],
              ),
            ),
            SkeletonBox(width: 70, height: 24, borderRadius: AppRadii.pill),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        const Center(child: SkeletonBox(width: 180, height: 180, borderRadius: 90)),
        const SizedBox(height: AppSpacing.lg),
        Center(child: Text('Connecting to your BotDyNax robot…', style: Theme.of(context).textTheme.bodyMedium)),
        const SizedBox(height: AppSpacing.lg),
        const GlassCard(child: SkeletonBox(height: 84)),
        const SizedBox(height: AppSpacing.md),
        const Row(
          children: [
            Expanded(child: GlassCard(child: SkeletonBox(height: 40))),
            SizedBox(width: AppSpacing.sm),
            Expanded(child: GlassCard(child: SkeletonBox(height: 40))),
          ],
        ),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Text('Unable to reach your robot.\n$message', textAlign: TextAlign.center),
      ),
    );
  }
}

class _DashboardView extends ConsumerWidget {
  const _DashboardView({required this.status});

  final RobotStatus status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final RobotController controller = ref.read(robotControllerProvider);
    final ThemeData theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        _Header(status: status),
        const SizedBox(height: AppSpacing.lg),
        Center(child: RobotIllustration(activity: status.activity)),
        const SizedBox(height: AppSpacing.sm),
        Center(
          child: Text(_activityLabel(status.activity), style: theme.textTheme.headlineSmall),
        ),
        if (status.currentTask != null || status.currentRoom != null) ...[
          const SizedBox(height: AppSpacing.xxs),
          Center(
            child: Text(
              [status.currentTask, status.currentRoom].nonNulls.join(' · '),
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
        if (status.hasErrors) ...[
          const SizedBox(height: AppSpacing.md),
          _ErrorBanner(status: status),
        ],
        const SizedBox(height: AppSpacing.lg),
        GlassCard(
          glowColor: AppColors.neonCyan,
          child: Column(
            children: [
              Row(
                children: [
                  AnimatedProgressRing(
                    value: status.batteryPercent,
                    size: 84,
                    color: status.batteryPercent < 0.2 ? AppColors.danger : AppColors.neonCyan,
                    center: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('${(status.batteryPercent * 100).round()}%', style: theme.textTheme.titleMedium),
                        if (status.isCharging) const Icon(Icons.bolt, size: 14, color: AppColors.warning),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            SignalIndicator(icon: Icons.wifi_rounded, signal: status.wifiSignal),
                            const SizedBox(width: AppSpacing.md),
                            SignalIndicator(icon: Icons.bluetooth_rounded, signal: status.bleSignal),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text('Firmware ${status.firmwareVersion}', style: theme.textTheme.bodySmall),
                        const SizedBox(height: 2),
                        Text(_vacuumModeLabel(status.vacuumPower), style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: AppSpacing.sm,
          crossAxisSpacing: AppSpacing.sm,
          // A fixed aspect ratio can't grow when the user's text scale
          // pushes tile content taller than the slot, which overflows by a
          // few pixels. Shrinking the ratio as text scales keeps the tiles
          // proportional at default size but lets them get taller when
          // accessibility text settings demand it.
          childAspectRatio: 2.4 / MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.6),
          children: [
            _HubTile(
              label: 'Live Map',
              icon: Icons.map_rounded,
              heroTag: 'live-map-icon',
              onTap: () => context.push(AppRoutes.map),
            ),
            _HubTile(
              label: 'Schedules',
              icon: Icons.calendar_month_rounded,
              onTap: () => context.push(AppRoutes.schedule),
            ),
            _HubTile(
              label: 'History',
              icon: Icons.history_rounded,
              onTap: () => context.push(AppRoutes.history),
            ),
            _HubTile(
              label: 'Accessories',
              icon: Icons.build_circle_outlined,
              onTap: () => context.push(AppRoutes.accessories),
            ),
            _HubTile(
              label: 'Diagnostics',
              icon: Icons.monitor_heart_outlined,
              onTap: () => context.push(AppRoutes.diagnostics),
            ),
            _HubTile(
              label: 'Settings',
              icon: Icons.settings_outlined,
              onTap: () => context.push(AppRoutes.settings),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(child: _MiniStat(label: 'Area Cleaned', value: '${status.areaCleanedSqm.toStringAsFixed(1)} m²')),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: _MiniStat(label: 'Cleaning Time', value: _formatShort(status.cleaningElapsed))),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: _MiniStat(label: 'Remaining', value: _formatShort(status.cleaningRemaining))),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        // Deliberately NOT dust-bin / water-tank fill percentages: this
        // robot has no DP for either, so those tiles could only ever show
        // a hardcoded 0%. These two are real — `water_output` and the
        // mop-pad fault code both come straight off the device.
        Row(
          children: [
            Expanded(child: _MiniStat(label: 'Water Level', value: _waterLabel(status.waterFlow))),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _MiniStat(
                label: 'Mop Pads',
                value: status.faultCodes.contains(21) ? 'Removed' : 'Fitted',
              ),
            ),
          ],
        ),
        if (status.consumables.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          Text('Accessories', style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          GlassCard(
            child: Column(
              children: [
                for (final (int index, Consumable consumable) in status.consumables.indexed) ...[
                  ConsumableTile(consumable: consumable),
                  if (index != status.consumables.length - 1) const SizedBox(height: AppSpacing.sm),
                ],
              ],
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        Text('Quick Actions', style: theme.textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        _QuickActions(status: status, controller: controller),
      ],
    );
  }

  String _waterLabel(WaterFlow flow) => switch (flow) {
        WaterFlow.off => 'Off',
        WaterFlow.low => 'Low',
        WaterFlow.medium => 'Medium',
        WaterFlow.high || WaterFlow.ultra => 'High',
      };

  String _activityLabel(ActivityState activity) => switch (activity) {
        ActivityState.idle => 'Idle',
        ActivityState.cleaning => 'Cleaning',
        ActivityState.paused => 'Paused',
        ActivityState.returningToDock => 'Returning to Dock',
        ActivityState.docked => 'Docked',
        ActivityState.charging => 'Charging',
        ActivityState.error => 'Attention Needed',
      };

  String _vacuumModeLabel(VacuumPower power) => switch (power) {
        VacuumPower.silent => 'Silent mode',
        VacuumPower.eco => 'Eco mode',
        VacuumPower.standard => 'Standard mode',
        VacuumPower.strong => 'Strong mode',
        VacuumPower.turbo => 'Turbo mode',
        VacuumPower.maximum => 'Maximum mode',
        VacuumPower.custom => 'Custom power',
      };

  String _formatShort(Duration duration) {
    final int hours = duration.inHours;
    final int minutes = duration.inMinutes.remainder(60);
    if (hours > 0) return '${hours}h ${minutes}m';
    return '${minutes}m';
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.status});

  final RobotStatus status;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      glowColor: AppColors.danger,
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: AppColors.danger),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            // Prefer the robot's own decoded fault text ("Sewage tank
            // removed") over the generic per-error-code message, which is
            // only a fallback for robots that report no specific cause.
            child: Text(
              status.faultMessages.isNotEmpty
                  ? status.faultMessages.join('\n')
                  : status.activeErrors.map((RobotErrorCode e) => e.message).join('\n'),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
  }
}

class _HubTile extends StatelessWidget {
  const _HubTile({required this.label, required this.icon, required this.onTap, this.heroTag});

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Object? heroTag;

  @override
  Widget build(BuildContext context) {
    final Widget iconWidget = Icon(icon, color: AppColors.neonCyan);

    return GlassCard(
      onTap: onTap,
      child: Row(
        children: [
          heroTag != null ? Hero(tag: heroTag!, child: iconWidget) : iconWidget,
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.titleSmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.status});

  final RobotStatus status;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Good day', style: theme.textTheme.bodyMedium),
              Text(status.name, style: theme.textTheme.displaySmall),
            ],
          ),
        ),
        StatusPill(
          label: status.isOnline ? 'Online' : 'Offline',
          color: status.isOnline ? AppColors.success : AppColors.textTertiaryDark,
          pulsing: status.isCleaning,
        ),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value, style: theme.textTheme.titleLarge),
          Text(label, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.status, required this.controller});

  final RobotStatus status;
  final RobotController controller;

  @override
  Widget build(BuildContext context) {
    final bool isCleaning = status.activity == ActivityState.cleaning;
    final bool isPaused = status.activity == ActivityState.paused;

    return Column(
      children: [
        if (isCleaning)
          BdPrimaryButton(label: 'Pause', icon: Icons.pause_rounded, onPressed: controller.pause)
        else if (isPaused)
          BdPrimaryButton(label: 'Resume', icon: Icons.play_arrow_rounded, onPressed: controller.resume)
        else
          BdPrimaryButton(
            label: 'Start Cleaning',
            icon: Icons.play_arrow_rounded,
            onPressed: controller.startCleaning,
          ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: BdSecondaryButton(
                label: 'Return to Dock',
                icon: Icons.home_rounded,
                onPressed: controller.returnToDock,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            BdIconButton(icon: Icons.location_searching_rounded, onPressed: controller.findRobot, tooltip: 'Find Robot'),
            const SizedBox(width: AppSpacing.sm),
            BdIconButton(
              icon: Icons.stop_rounded,
              onPressed: isCleaning || isPaused ? controller.stop : null,
              tooltip: 'Stop',
            ),
            const SizedBox(width: AppSpacing.sm),
            BdIconButton(
              icon: status.isChildLockOn ? Icons.lock_rounded : Icons.lock_open_rounded,
              active: status.isChildLockOn,
              onPressed: () => controller.setChildLock(!status.isChildLockOn),
              tooltip: 'Child Lock',
            ),
          ],
        ),
      ],
    );
  }
}

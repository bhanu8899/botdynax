import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/skeleton_loader.dart';
import '../../domain/entities/cleaning_schedule.dart';
import '../../domain/repositories/schedule_repository.dart';
import '../providers/cloud_providers.dart';
import 'widgets/schedule_editor_sheet.dart';

class ScheduleScreen extends ConsumerWidget {
  const ScheduleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<String?> robotIdAsync = ref.watch(backendRobotIdProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Schedules')),
      body: robotIdAsync.when(
        loading: () => const SkeletonList(),
        error: (Object error, StackTrace _) => Center(child: Text('Unable to sync robot.\n$error')),
        data: (String? robotId) {
          if (robotId == null) {
            return const Center(child: Text('Connect a robot first.'));
          }
          return _ScheduleList(robotId: robotId);
        },
      ),
      floatingActionButton: robotIdAsync.valueOrNull == null
          ? null
          : FloatingActionButton(
              backgroundColor: AppColors.neonCyan,
              onPressed: () => _createSchedule(context, ref, robotIdAsync.requireValue!),
              child: const Icon(Icons.add, color: Colors.black),
            ),
    );
  }

  Future<void> _createSchedule(BuildContext context, WidgetRef ref, String robotId) async {
    final CleaningSchedule? result = await showModalBottomSheet<CleaningSchedule>(
      context: context,
      isScrollControlled: true,
      builder: (_) => ScheduleEditorSheet(initial: defaultNewSchedule()),
    );
    if (result == null) return;
    await ref.read(scheduleRepositoryProvider).create(robotId, result);
    ref.invalidate(schedulesProvider(robotId));
  }
}

class _ScheduleList extends ConsumerWidget {
  const _ScheduleList({required this.robotId});

  final String robotId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<CleaningSchedule>> schedulesAsync = ref.watch(schedulesProvider(robotId));

    return schedulesAsync.when(
      loading: () => const SkeletonList(),
      error: (Object error, StackTrace _) => Center(child: Text('Unable to load schedules.\n$error')),
      data: (List<CleaningSchedule> schedules) {
        if (schedules.isEmpty) {
          return const Center(child: Text('No schedules yet. Tap + to add one.'));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(AppSpacing.md),
          itemCount: schedules.length,
          separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
          itemBuilder: (BuildContext context, int index) {
            final CleaningSchedule schedule = schedules[index];
            return _ScheduleTile(robotId: robotId, schedule: schedule);
          },
        );
      },
    );
  }
}

class _ScheduleTile extends ConsumerWidget {
  const _ScheduleTile({required this.robotId, required this.schedule});

  final String robotId;
  final CleaningSchedule schedule;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);

    return GlassCard(
      onTap: () => _edit(context, ref),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(schedule.label, style: theme.textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(
                  '${schedule.time} · ${schedule.recurrenceSummary} · ${schedule.mode.name}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Switch(
            value: schedule.enabled,
            activeThumbColor: AppColors.neonCyan,
            onChanged: (bool value) async {
              await ref.read(scheduleRepositoryProvider).update(robotId, schedule.copyWith(enabled: value));
              ref.invalidate(schedulesProvider(robotId));
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: () async {
              await ref.read(scheduleRepositoryProvider).remove(robotId, schedule.id);
              ref.invalidate(schedulesProvider(robotId));
            },
          ),
        ],
      ),
    );
  }

  Future<void> _edit(BuildContext context, WidgetRef ref) async {
    final CleaningSchedule? result = await showModalBottomSheet<CleaningSchedule>(
      context: context,
      isScrollControlled: true,
      builder: (_) => ScheduleEditorSheet(initial: schedule),
    );
    if (result == null) return;
    await ref.read(scheduleRepositoryProvider).update(robotId, result);
    ref.invalidate(schedulesProvider(robotId));
  }
}

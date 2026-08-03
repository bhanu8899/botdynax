import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/skeleton_loader.dart';
import '../../domain/entities/cleaning_session.dart';
import '../providers/cloud_providers.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<String?> robotIdAsync = ref.watch(backendRobotIdProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Cleaning History')),
      body: robotIdAsync.when(
        loading: () => const SkeletonList(),
        error: (Object error, StackTrace _) => Center(child: Text('Unable to sync robot.\n$error')),
        data: (String? robotId) {
          if (robotId == null) {
            return const Center(child: Text('Connect a robot first.'));
          }
          return _HistoryList(robotId: robotId);
        },
      ),
    );
  }
}

class _HistoryList extends ConsumerWidget {
  const _HistoryList({required this.robotId});

  final String robotId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<CleaningSession>> historyAsync = ref.watch(cleaningHistoryProvider(robotId));

    return historyAsync.when(
      loading: () => const SkeletonList(),
      error: (Object error, StackTrace _) => Center(child: Text('Unable to load history.\n$error')),
      data: (List<CleaningSession> sessions) {
        if (sessions.isEmpty) {
          return const Center(child: Text('No cleaning runs recorded yet.'));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(AppSpacing.md),
          itemCount: sessions.length,
          separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
          itemBuilder: (BuildContext context, int index) => _SessionTile(session: sessions[index]),
        );
      },
    );
  }
}

class _SessionTile extends StatelessWidget {
  const _SessionTile({required this.session});

  final CleaningSession session;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool hasErrors = session.errors.isNotEmpty;

    return GlassCard(
      glowColor: hasErrors ? AppColors.danger : null,
      child: Row(
        children: [
          Container(
            height: 44,
            width: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: (hasErrors ? AppColors.danger : AppColors.neonCyan).withValues(alpha: 0.15),
            ),
            child: Icon(
              hasErrors ? Icons.warning_amber_rounded : Icons.check_rounded,
              color: hasErrors ? AppColors.danger : AppColors.neonCyan,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormat.yMMMd().add_jm().format(session.startedAt),
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  '${session.areaCleanedSqm.toStringAsFixed(1)} m² · '
                  '${session.duration.inMinutes}m · '
                  '${(session.batteryUsedPercent).round()}% battery',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          if (session.cleaningScore != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${session.cleaningScore}', style: theme.textTheme.titleLarge),
                Text('score', style: theme.textTheme.bodySmall),
              ],
            ),
        ],
      ),
    );
  }
}

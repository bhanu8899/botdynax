import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/bd_buttons.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/skeleton_loader.dart';
import '../../domain/entities/consumable.dart';
import '../../domain/entities/robot_status.dart';
import '../home/widgets/consumable_tile.dart';
import '../providers/cloud_providers.dart';
import '../providers/robot_providers.dart';

class AccessoriesScreen extends ConsumerWidget {
  const AccessoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<RobotStatus> statusAsync = ref.watch(robotStatusProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Accessories')),
      body: statusAsync.when(
        loading: () => const SkeletonList(),
        error: (Object error, StackTrace _) => Center(child: Text('Unable to load status.\n$error')),
        data: (RobotStatus status) {
          if (status.consumables.isEmpty) {
            return const Center(child: Text('No accessory data reported yet.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: status.consumables.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (BuildContext context, int index) {
              return _AccessoryCard(consumable: status.consumables[index]);
            },
          );
        },
      ),
    );
  }
}

class _AccessoryCard extends ConsumerWidget {
  const _AccessoryCard({required this.consumable});

  final Consumable consumable;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final int ratedHours = consumable.ratedLifetimeMinutes ~/ 60;
    final int usedHours = consumable.usedMinutes ~/ 60;

    return GlassCard(
      glowColor: consumable.needsReplacement ? AppColors.danger : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ConsumableTile(consumable: consumable),
          const SizedBox(height: AppSpacing.sm),
          Text('$usedHours of $ratedHours hours used', style: theme.textTheme.bodySmall),
          if (consumable.needsReplacement) ...[
            const SizedBox(height: AppSpacing.sm),
            BdSecondaryButton(
              label: 'Mark as Replaced',
              icon: Icons.check_circle_outline_rounded,
              onPressed: () => _markReplaced(context, ref),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _markReplaced(BuildContext context, WidgetRef ref) async {
    final String? robotId = ref.read(backendRobotIdProvider).valueOrNull;
    if (robotId == null) return;
    await ref.read(accessoryRepositoryProvider).sync(robotId, consumable);
    await ref.read(accessoryRepositoryProvider).markReplaced(robotId, consumable.type);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${consumable.label} marked as replaced')),
      );
    }
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/skeleton_loader.dart';
import '../../domain/entities/app_notification.dart';
import '../providers/cloud_providers.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  IconData _iconFor(NotificationType type) => switch (type) {
        NotificationType.cleaningStarted => Icons.play_circle_outline_rounded,
        NotificationType.cleaningCompleted => Icons.check_circle_outline_rounded,
        NotificationType.lowBattery => Icons.battery_alert_rounded,
        NotificationType.brushReplacement => Icons.cyclone_rounded,
        NotificationType.filterReplacement => Icons.air_rounded,
        NotificationType.waterEmpty => Icons.water_drop_outlined,
        NotificationType.dustBinFull => Icons.delete_outline_rounded,
        NotificationType.robotOffline => Icons.wifi_off_rounded,
        NotificationType.firmwareAvailable => Icons.system_update_rounded,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<AppNotification>> notificationsAsync = ref.watch(notificationsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: notificationsAsync.when(
        loading: () => const SkeletonList(),
        error: (Object error, StackTrace _) => Center(child: Text('Unable to load notifications.\n$error')),
        data: (List<AppNotification> notifications) {
          if (notifications.isEmpty) {
            return const Center(child: Text('No notifications yet.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: notifications.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (BuildContext context, int index) {
              final AppNotification notification = notifications[index];
              return GlassCard(
                onTap: notification.read
                    ? null
                    : () async {
                        await ref.read(notificationRepositoryProvider).markRead(notification.id);
                        ref.invalidate(notificationsProvider);
                      },
                glowColor: notification.read ? null : AppColors.neonCyan,
                child: Row(
                  children: [
                    Icon(_iconFor(notification.type), color: AppColors.neonCyan),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(notification.type.label, style: Theme.of(context).textTheme.titleMedium),
                          Text(notification.message, style: Theme.of(context).textTheme.bodySmall),
                          Text(
                            DateFormat.yMMMd().add_jm().format(notification.createdAt),
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ],
                      ),
                    ),
                    if (!notification.read)
                      const Icon(Icons.circle, size: 8, color: AppColors.neonCyan),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

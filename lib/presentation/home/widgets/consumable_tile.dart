import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../domain/entities/consumable.dart';
import '../../../domain/entities/robot_enums.dart';

class ConsumableTile extends StatelessWidget {
  const ConsumableTile({required this.consumable, super.key});

  final Consumable consumable;

  IconData get _icon => switch (consumable.type) {
        ConsumableType.mainBrush => Icons.cyclone_rounded,
        ConsumableType.sideBrush => Icons.blur_circular_rounded,
        ConsumableType.filter => Icons.air_rounded,
        ConsumableType.mopPad => Icons.water_drop_outlined,
        ConsumableType.battery => Icons.battery_full_rounded,
        ConsumableType.sensor => Icons.sensors_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color color = consumable.needsReplacement ? AppColors.danger : AppColors.neonCyan;

    return Row(
      children: [
        Icon(_icon, size: 18, color: color),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(consumable.label, style: theme.textTheme.labelLarge),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadii.pill),
                child: LinearProgressIndicator(
                  value: consumable.remainingPercent.clamp(0, 1),
                  minHeight: 5,
                  backgroundColor: AppColors.darkSurfaceHigh,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          '${(consumable.remainingPercent * 100).round()}%',
          style: theme.textTheme.labelMedium?.copyWith(color: color),
        ),
      ],
    );
  }
}

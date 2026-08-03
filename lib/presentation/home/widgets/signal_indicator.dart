import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../domain/entities/robot_status.dart';

/// Compact bar-style signal strength readout (0-4 bars), used for both
/// WiFi and BLE link quality.
class SignalIndicator extends StatelessWidget {
  const SignalIndicator({required this.icon, required this.signal, super.key});

  final IconData icon;
  final SignalStrength signal;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color track = isDark ? AppColors.darkSurfaceHigh : AppColors.lightSurfaceHigh;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
        const SizedBox(width: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(4, (int index) {
            final bool filled = index < signal.bars;
            return Container(
              margin: const EdgeInsets.only(right: 2),
              width: 3,
              height: 5.0 + index * 3,
              decoration: BoxDecoration(
                color: filled ? AppColors.neonCyan : track,
                borderRadius: BorderRadius.circular(1),
              ),
            );
          }),
        ),
      ],
    );
  }
}

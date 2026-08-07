import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/bd_buttons.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../domain/entities/robot_enums.dart';
import '../../../domain/entities/robot_status.dart';
import '../../providers/robot_providers.dart';

/// The floating "bottom control panel" — cleaning-mode selector plus the
/// full set of run controls, overlaid on the Live Map so you can watch the
/// robot while commanding it.
class BottomControlPanel extends StatelessWidget {
  const BottomControlPanel({
    required this.status,
    required this.controller,
    required this.selectedRoomId,
    super.key,
  });

  final RobotStatus status;
  final RobotController controller;
  final String? selectedRoomId;

  bool get _isCleaning => status.activity == ActivityState.cleaning;
  bool get _isPaused => status.activity == ActivityState.paused;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      glowColor: AppColors.neonCyan,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _ModeChip(
                  label: 'Auto',
                  icon: Icons.auto_awesome_rounded,
                  onTap: () => controller.startCleaning(mode: CleaningMode.auto),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: _ModeChip(
                  label: 'Room',
                  icon: Icons.door_front_door_outlined,
                  onTap: selectedRoomId == null
                      ? controller.selectRoomClean
                      : () => controller.roomClean([selectedRoomId!]),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: _ModeChip(
                  label: 'Zone',
                  icon: Icons.crop_square_rounded,
                  onTap: () => controller.zoneClean(const []),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: _ModeChip(
                  label: 'Spot',
                  icon: Icons.center_focus_strong_rounded,
                  onTap: controller.spotClean,
                ),
              ),
            ],
          ),
          // Manual / Preferences / Station used to sit here too. They now
          // live on the Home dashboard, so duplicating them inside the
          // map panel just crowded it — the map keeps only the controls
          // that are actually about the map (cleaning modes + run state).
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: _isCleaning
                    ? BdPrimaryButton(label: 'Pause', icon: Icons.pause_rounded, onPressed: controller.pause)
                    : _isPaused
                        ? BdPrimaryButton(
                            label: 'Resume',
                            icon: Icons.play_arrow_rounded,
                            onPressed: controller.resume,
                          )
                        : BdPrimaryButton(
                            label: 'Start',
                            icon: Icons.play_arrow_rounded,
                            onPressed: controller.startCleaning,
                          ),
              ),
              const SizedBox(width: AppSpacing.xs),
              BdIconButton(
                icon: Icons.stop_rounded,
                onPressed: _isCleaning || _isPaused ? controller.stop : null,
                tooltip: 'Stop',
              ),
              const SizedBox(width: AppSpacing.xs),
              BdIconButton(icon: Icons.home_rounded, onPressed: controller.returnToDock, tooltip: 'Return to Dock'),
              const SizedBox(width: AppSpacing.xs),
              BdIconButton(
                icon: Icons.location_searching_rounded,
                onPressed: controller.findRobot,
                tooltip: 'Find Robot',
              ),
              const SizedBox(width: AppSpacing.xs),
              BdIconButton(
                icon: Icons.warning_amber_rounded,
                onPressed: controller.emergencyStop,
                tooltip: 'Emergency Stop',
              ),
            ],
          ),
        ],
      ),
    );
  }

}

class _ModeChip extends StatelessWidget {
  const _ModeChip({required this.label, required this.icon, required this.onTap});

  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Opacity(
        opacity: onTap == null ? 0.4 : 1,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: AppColors.neonCyan),
            const SizedBox(height: 2),
            Text(label, style: Theme.of(context).textTheme.labelSmall),
          ],
        ),
      ),
    );
  }
}

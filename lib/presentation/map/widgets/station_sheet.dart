import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../domain/entities/robot_status.dart';
import '../../providers/robot_providers.dart';

/// Docking station popup — dust collection, mop washing, mop drying.
/// Every action here maps to a real, confirmed Tuya data point
/// (`manual_dust_collection`, `wash`, `manual_air`), and the auto-toggles
/// map to `auto_dust_collection`/`auto_air`. There is no matching
/// auto-wash DP on this device (only the manual trigger exists), so that
/// toggle is intentionally not offered.
///
/// `manual_dust_collection` itself is a write-only *trigger* ("collect
/// now"), not a bag-presence status field — confirmed via the device's
/// real thing model (`{type: "bool"}`, no read-back semantics documented
/// or observed). The dust-bag-missing state shown here instead comes from
/// `total_error` code 18 ([RobotStatus.isDustBagMissing]), which is the
/// signal empirically confirmed to track the dock's dust bag being
/// physically removed — and it updates in real time on every status poll.
class StationSheet extends StatefulWidget {
  const StationSheet({required this.status, required this.controller, super.key});

  final RobotStatus status;
  final RobotController controller;

  @override
  State<StationSheet> createState() => _StationSheetState();
}

class _StationSheetState extends State<StationSheet> {
  late bool _autoDust = widget.status.autoDustCollection;
  late bool _autoDry = widget.status.autoMopDry;

  Future<void> _run(String label, Future<void> Function() action) async {
    await action();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$label sent to the dock')));
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Docking Station', style: theme.textTheme.headlineSmall),
            const SizedBox(height: AppSpacing.lg),
            _ActionTile(
              icon: Icons.compress_rounded,
              label: 'Dust Collection',
              subtitle: widget.status.isDustBagMissing
                  ? 'Dust bag missing — reinstall it to enable'
                  : 'Empty the dust bin into the base now',
              enabled: !widget.status.isDustBagMissing,
              onTap: () => _run('Dust collection', widget.controller.triggerDustCollection),
            ),
            const SizedBox(height: AppSpacing.sm),
            _ActionTile(
              icon: Icons.local_car_wash_rounded,
              label: 'Mop Washing',
              subtitle: widget.status.isMopPadsRemoved
                  ? 'Mop pads missing — reinstall them to enable'
                  : 'Rinse the mop pads at the dock',
              enabled: !widget.status.isMopPadsRemoved,
              onTap: () => _run('Mop washing', widget.controller.triggerMopWash),
            ),
            const SizedBox(height: AppSpacing.sm),
            _ActionTile(
              icon: Icons.air_rounded,
              label: 'Mop Drying (Warm Air)',
              subtitle: 'Dry the mop pads to prevent odour',
              onTap: () => _run('Mop drying', widget.controller.triggerMopDry),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Automatic', style: theme.textTheme.labelLarge),
            const SizedBox(height: AppSpacing.sm),
            GlassCard(
              child: Column(
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Auto dust collection'),
                    subtitle: const Text('Empty the bin after every clean'),
                    activeThumbColor: AppColors.neonCyan,
                    value: _autoDust,
                    onChanged: (bool v) {
                      setState(() => _autoDust = v);
                      widget.controller.setAutoDustCollection(v);
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Auto mop drying'),
                    subtitle: const Text('Dry the pads after washing'),
                    activeThumbColor: AppColors.neonCyan,
                    value: _autoDry,
                    onChanged: (bool v) {
                      setState(() => _autoDry = v);
                      widget.controller.setAutoMopDry(v);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final Color tint = enabled ? AppColors.neonCyan : AppColors.danger;
    return GlassCard(
      onTap: enabled ? onTap : null,
      glowColor: enabled ? null : AppColors.danger,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: tint.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: tint),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.titleSmall),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: enabled ? null : AppColors.danger),
                ),
              ],
            ),
          ),
          if (enabled) const Icon(Icons.chevron_right_rounded, color: Colors.white38),
        ],
      ),
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/bd_buttons.dart';
import '../../core/widgets/glass_card.dart';
import '../providers/robot_providers.dart';

/// Manual drive pad. Buttons map directly to the real `direction_control`
/// DP (`forward | turn_left | turn_right | stop` — confirmed via the
/// device's full v2.0 thing model, no reverse/backward value exists on
/// this device, so no Backward button is offered here; faking one would
/// silently do nothing when pressed). The LED, vacuum-motor, water-pump
/// toggles and the drive-speed slider previously on this screen were
/// removed for the same reason: none of those DPs exist on this device
/// either (`direction_control` carries no speed/magnitude, and there is no
/// `led`/motor/pump DP anywhere in the 37-DP model) — they were UI that
/// silently did nothing when pressed.
class RemoteControlScreen extends ConsumerWidget {
  const RemoteControlScreen({super.key});

  RobotController _controller(WidgetRef ref) => ref.read(robotControllerProvider);

  Future<void> _send(WidgetRef ref, {required double linear, required double angular}) =>
      _controller(ref).drive(linear: linear, angular: angular);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Remote Control')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            children: [
              const Spacer(),
              _DirectionPad(
                onForward: () => unawaited(_send(ref, linear: 1, angular: 0)),
                onTurnLeft: () => unawaited(_send(ref, linear: 0, angular: -1)),
                onTurnRight: () => unawaited(_send(ref, linear: 0, angular: 1)),
                onStop: () => unawaited(_send(ref, linear: 0, angular: 0)),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'This robot has no reverse — only forward, turn, and stop.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondaryDark),
              ),
              const Spacer(),
              BdSecondaryButton(
                label: 'Return to Dock',
                icon: Icons.home_rounded,
                onPressed: () => unawaited(_controller(ref).returnToDock()),
              ),
              const SizedBox(height: AppSpacing.sm),
              BdSecondaryButton(
                label: 'Find Robot',
                icon: Icons.campaign_rounded,
                onPressed: () => unawaited(_controller(ref).findRobot()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DirectionPad extends StatelessWidget {
  const _DirectionPad({
    required this.onForward,
    required this.onTurnLeft,
    required this.onTurnRight,
    required this.onStop,
  });

  final VoidCallback onForward;
  final VoidCallback onTurnLeft;
  final VoidCallback onTurnRight;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    const double buttonSize = 76;
    return GlassCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PadButton(icon: Icons.keyboard_arrow_up_rounded, size: buttonSize, onPressed: onForward),
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _PadButton(icon: Icons.rotate_left_rounded, size: buttonSize, onPressed: onTurnLeft),
              const SizedBox(width: AppSpacing.sm),
              _PadButton(
                icon: Icons.stop_rounded,
                size: buttonSize,
                color: AppColors.danger,
                onPressed: onStop,
              ),
              const SizedBox(width: AppSpacing.sm),
              _PadButton(icon: Icons.rotate_right_rounded, size: buttonSize, onPressed: onTurnRight),
            ],
          ),
        ],
      ),
    );
  }
}

class _PadButton extends StatelessWidget {
  const _PadButton({required this.icon, required this.size, required this.onPressed, this.color});

  final IconData icon;
  final double size;
  final VoidCallback onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final Color tint = color ?? AppColors.neonCyan;
    return Material(
      color: tint.withValues(alpha: 0.12),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(icon, size: size * 0.5, color: tint),
        ),
      ),
    );
  }
}

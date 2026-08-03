import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/bd_buttons.dart';
import '../../core/widgets/glass_card.dart';
import '../providers/robot_providers.dart';
import 'widgets/joystick_pad.dart';

class RemoteControlScreen extends ConsumerStatefulWidget {
  const RemoteControlScreen({super.key});

  @override
  ConsumerState<RemoteControlScreen> createState() => _RemoteControlScreenState();
}

class _RemoteControlScreenState extends ConsumerState<RemoteControlScreen> {
  double _speed = 0.6;
  bool _vacuumOn = false;
  bool _waterOn = false;
  bool _ledOn = false;

  RobotController get _controller => ref.read(robotControllerProvider);

  void _handleJoystick(double linear, double angular) {
    unawaited(_controller.drive(linear: linear * _speed, angular: angular * _speed));
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Remote Control')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _ToggleTile(
                      label: 'Vacuum',
                      icon: Icons.cyclone_rounded,
                      value: _vacuumOn,
                      onChanged: (bool value) {
                        setState(() => _vacuumOn = value);
                        unawaited(_controller.setVacuumMotor(value));
                      },
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _ToggleTile(
                      label: 'Water',
                      icon: Icons.water_drop_outlined,
                      value: _waterOn,
                      onChanged: (bool value) {
                        setState(() => _waterOn = value);
                        unawaited(_controller.setWaterPump(value));
                      },
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _ToggleTile(
                      label: 'LED',
                      icon: Icons.lightbulb_outline_rounded,
                      value: _ledOn,
                      onChanged: (bool value) {
                        setState(() => _ledOn = value);
                        unawaited(_controller.setLed(value));
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              Expanded(
                child: Center(
                  child: JoystickPad(onChanged: _handleJoystick),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.speed_rounded, size: 18, color: AppColors.neonCyan),
                        const SizedBox(width: AppSpacing.xs),
                        Text('Drive Speed', style: theme.textTheme.labelLarge),
                        const Spacer(),
                        Text('${(_speed * 100).round()}%', style: theme.textTheme.labelLarge),
                      ],
                    ),
                    Slider(
                      value: _speed,
                      min: 0.2,
                      max: 1.0,
                      activeColor: AppColors.neonCyan,
                      onChanged: (double value) => setState(() => _speed = value),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              BdSecondaryButton(
                label: 'Return to Dock',
                icon: Icons.home_rounded,
                onPressed: () => unawaited(_controller.returnToDock()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToggleTile extends StatelessWidget {
  const _ToggleTile({
    required this.label,
    required this.icon,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final IconData icon;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: () => onChanged(!value),
      glowColor: value ? AppColors.neonCyan : null,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Column(
        children: [
          Icon(icon, color: value ? AppColors.neonCyan : null),
          const SizedBox(height: AppSpacing.xxs),
          Text(label, style: Theme.of(context).textTheme.labelMedium),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/bd_buttons.dart';
import '../../../domain/entities/robot_enums.dart';
import '../../../domain/entities/robot_status.dart';

/// Cleaning preferences popup — cleaning type, suction, water level, and
/// pass count. Every option here is a real, writable Tuya data point on
/// the Milagrow W300 (`sweep_mop_mode`, `suction`, `water_output`,
/// `clean_times`), confirmed against the device's full thing model.
/// Saving sends all four in one go.
class CleaningPreferencesSheet extends StatefulWidget {
  const CleaningPreferencesSheet({required this.status, super.key});

  final RobotStatus status;

  @override
  State<CleaningPreferencesSheet> createState() => _CleaningPreferencesSheetState();
}

class _CleaningPreferencesSheetState extends State<CleaningPreferencesSheet> {
  late CleaningType _type = widget.status.cleaningType;
  late VacuumPower _power = widget.status.vacuumPower;
  late WaterFlow _water = widget.status.waterFlow;
  late int _passes = widget.status.cleaningPasses;

  bool get _mopInvolved => _type != CleaningType.vacuum;
  bool get _vacuumInvolved => _type != CleaningType.mop;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.lg,
          right: AppSpacing.lg,
          top: AppSpacing.lg,
          bottom: AppSpacing.lg + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Cleaning Preferences', style: theme.textTheme.headlineSmall),
              const SizedBox(height: AppSpacing.lg),
              Text('Cleaning Type', style: theme.textTheme.labelLarge),
              const SizedBox(height: AppSpacing.sm),
              _SegmentedRow<CleaningType>(
                value: _type,
                options: const [
                  (CleaningType.vacuum, 'Vacuum', Icons.air_rounded),
                  (CleaningType.mop, 'Mop', Icons.water_drop_outlined),
                  (CleaningType.vacuumAndMop, 'Vacuum & Mop', Icons.auto_awesome_rounded),
                  (CleaningType.mopAfterVacuum, 'Mop after Vacuum', Icons.repeat_rounded),
                ],
                onChanged: (CleaningType v) => setState(() => _type = v),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Suction Power',
                style: theme.textTheme.labelLarge?.copyWith(color: _vacuumInvolved ? null : Colors.white38),
              ),
              const SizedBox(height: AppSpacing.sm),
              Opacity(
                opacity: _vacuumInvolved ? 1 : 0.4,
                child: IgnorePointer(
                  ignoring: !_vacuumInvolved,
                  child: _SegmentedRow<VacuumPower>(
                    value: _power,
                    options: const [
                      (VacuumPower.eco, 'Quiet', Icons.volume_down_rounded),
                      (VacuumPower.standard, 'Standard', Icons.equalizer_rounded),
                      (VacuumPower.strong, 'Strong', Icons.bolt_rounded),
                      (VacuumPower.maximum, 'Max', Icons.local_fire_department_rounded),
                    ],
                    onChanged: (VacuumPower v) => setState(() => _power = v),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Water Output',
                style: theme.textTheme.labelLarge?.copyWith(color: _mopInvolved ? null : Colors.white38),
              ),
              const SizedBox(height: AppSpacing.sm),
              Opacity(
                opacity: _mopInvolved ? 1 : 0.4,
                child: IgnorePointer(
                  ignoring: !_mopInvolved,
                  child: _SegmentedRow<WaterFlow>(
                    value: _water,
                    options: const [
                      (WaterFlow.low, 'Low', Icons.opacity_rounded),
                      (WaterFlow.medium, 'Medium', Icons.water_drop_rounded),
                      (WaterFlow.high, 'High', Icons.waves_rounded),
                    ],
                    onChanged: (WaterFlow v) => setState(() => _water = v),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text('Cleaning Passes', style: theme.textTheme.labelLarge),
              const SizedBox(height: AppSpacing.sm),
              _SegmentedRow<int>(
                value: _passes,
                options: const [(1, '1×', Icons.looks_one_outlined), (2, '2×', Icons.looks_two_outlined)],
                onChanged: (int v) => setState(() => _passes = v),
              ),
              const SizedBox(height: AppSpacing.xl),
              BdPrimaryButton(
                label: 'Save',
                onPressed: () => Navigator.of(context).pop(
                  (type: _type, power: _power, water: _water, passes: _passes),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SegmentedRow<T> extends StatelessWidget {
  const _SegmentedRow({required this.value, required this.options, required this.onChanged});

  final T value;
  final List<(T, String, IconData)> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: [
        for (final (T optionValue, String label, IconData icon) in options)
          _SegmentChip(
            label: label,
            icon: icon,
            selected: optionValue == value,
            onTap: () => onChanged(optionValue),
          ),
      ],
    );
  }
}

class _SegmentChip extends StatelessWidget {
  const _SegmentChip({required this.label, required this.icon, required this.selected, required this.onTap});

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color borderColor = selected
        ? AppColors.neonCyan
        : (isDark ? AppColors.glassBorderDark : AppColors.glassBorderLight);
    final Color fill = selected
        ? AppColors.neonCyan.withValues(alpha: 0.16)
        : (isDark ? AppColors.glassFillDark : AppColors.glassFillLight);
    final Color textColor = selected
        ? AppColors.neonCyan
        : (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight);

    return Material(
      color: fill,
      borderRadius: BorderRadius.circular(AppRadii.pill),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.pill),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.pill),
            border: Border.all(color: borderColor, width: 1.2),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: textColor),
              const SizedBox(width: 6),
              Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: textColor)),
            ],
          ),
        ),
      ),
    );
  }
}

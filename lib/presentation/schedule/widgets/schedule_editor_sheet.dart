import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/bd_buttons.dart';
import '../../../domain/entities/cleaning_schedule.dart';
import '../../../domain/entities/robot_enums.dart';

/// Bottom sheet for creating or editing a [CleaningSchedule]. Returns the
/// edited schedule via [Navigator.pop], or null if cancelled.
class ScheduleEditorSheet extends StatefulWidget {
  const ScheduleEditorSheet({required this.initial, super.key});

  final CleaningSchedule initial;

  @override
  State<ScheduleEditorSheet> createState() => _ScheduleEditorSheetState();
}

class _ScheduleEditorSheetState extends State<ScheduleEditorSheet> {
  late final TextEditingController _labelController = TextEditingController(text: widget.initial.label);
  late final Set<int> _selectedDays = widget.initial.weekdays.toSet();
  late TimeOfDay _time = _parseTime(widget.initial.time);
  late CleaningMode _mode = widget.initial.mode;
  late VacuumPower _power = widget.initial.vacuumPower;
  late WaterFlow _water = widget.initial.waterLevel;
  late bool _enabled = widget.initial.enabled;
  late bool _notify = widget.initial.notify;

  TimeOfDay _parseTime(String value) {
    final List<String> parts = value.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  String _formatTime(TimeOfDay time) =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  void _save() {
    final String daysOfWeek = _selectedDays.length == 7
        ? 'DAILY'
        : (_selectedDays.toList()..sort()).join(',');

    Navigator.of(context).pop(
      widget.initial.copyWith(
        label: _labelController.text.trim().isEmpty ? 'Cleaning Schedule' : _labelController.text.trim(),
        daysOfWeek: daysOfWeek,
        time: _formatTime(_time),
        mode: _mode,
        vacuumPower: _power,
        waterLevel: _water,
        enabled: _enabled,
        notify: _notify,
      ),
    );
  }

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
              Text(
                widget.initial.id.isEmpty ? 'New Schedule' : 'Edit Schedule',
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _labelController,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: AppSpacing.md),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Time'),
                trailing: Text(_time.format(context), style: theme.textTheme.titleMedium),
                onTap: () async {
                  final TimeOfDay? picked = await showTimePicker(context: context, initialTime: _time);
                  if (picked != null) setState(() => _time = picked);
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              Text('Repeat', style: theme.textTheme.labelLarge),
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                spacing: AppSpacing.xs,
                children: List.generate(7, (int day) {
                  final bool selected = _selectedDays.contains(day);
                  return FilterChip(
                    label: Text(CleaningSchedule.weekdayLabels[day]),
                    selected: selected,
                    selectedColor: AppColors.neonCyan.withValues(alpha: 0.25),
                    onSelected: (bool value) {
                      setState(() {
                        if (value) {
                          _selectedDays.add(day);
                        } else {
                          _selectedDays.remove(day);
                        }
                      });
                    },
                  );
                }),
              ),
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<CleaningMode>(
                initialValue: _mode,
                decoration: const InputDecoration(labelText: 'Cleaning Mode'),
                items: CleaningMode.values
                    .map((CleaningMode m) => DropdownMenuItem(value: m, child: Text(m.name)))
                    .toList(),
                onChanged: (CleaningMode? value) => setState(() => _mode = value ?? _mode),
              ),
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<VacuumPower>(
                initialValue: _power,
                decoration: const InputDecoration(labelText: 'Suction Power'),
                items: VacuumPower.values
                    .map((VacuumPower p) => DropdownMenuItem(value: p, child: Text(p.name)))
                    .toList(),
                onChanged: (VacuumPower? value) => setState(() => _power = value ?? _power),
              ),
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<WaterFlow>(
                initialValue: _water,
                decoration: const InputDecoration(labelText: 'Water Level'),
                items: WaterFlow.values
                    .map((WaterFlow w) => DropdownMenuItem(value: w, child: Text(w.name)))
                    .toList(),
                onChanged: (WaterFlow? value) => setState(() => _water = value ?? _water),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Enabled'),
                value: _enabled,
                onChanged: (bool value) => setState(() => _enabled = value),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Notify when complete'),
                value: _notify,
                onChanged: (bool value) => setState(() => _notify = value),
              ),
              const SizedBox(height: AppSpacing.md),
              BdPrimaryButton(
                label: 'Save Schedule',
                onPressed: _selectedDays.isEmpty ? null : _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

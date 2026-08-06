import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/routing/app_routes.dart';
import '../../core/storage/local_storage_provider.dart';
import '../../core/storage/local_storage_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/glass_card.dart';
import '../../domain/entities/robot_enums.dart';
import '../../domain/entities/robot_status.dart';
import '../providers/auth_providers.dart';
import '../providers/auth_state.dart';
import '../providers/robot_providers.dart';
import '../providers/theme_mode_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late bool _developerMode = ref.read(localStorageServiceProvider).developerMode;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AuthState authState = ref.watch(authControllerProvider);
    final AsyncValue<RobotStatus> statusAsync = ref.watch(robotStatusProvider);
    final ThemeMode themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          const _SectionHeader(title: 'Account'),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(authState.user?.name ?? '—', style: theme.textTheme.titleMedium),
                Text(
                  authState.user?.email ?? 'Guest account',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: AppSpacing.sm),
                OutlinedButton(
                  onPressed: () => ref.read(authControllerProvider.notifier).logout(),
                  child: const Text('Log Out'),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          const _SectionHeader(title: 'Robot'),
          statusAsync.when(
            loading: () => const GlassCard(child: LinearProgressIndicator()),
            error: (Object _, StackTrace _) => const SizedBox.shrink(),
            data: (RobotStatus status) => GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SettingsRow(label: 'Name', value: status.name),
                  _SettingsRow(label: 'Firmware', value: status.firmwareVersion),
                  _SettingsRow(label: 'Robot ID', value: status.robotId),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          const _SectionHeader(title: 'Cloud Accounts'),
          GlassCard(
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.cloud_outlined, color: AppColors.neonCyan),
              title: const Text('Link Tuya Account'),
              subtitle: const Text('Connect a Tuya/Smart Life-based device'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => context.push(AppRoutes.tuyaLink),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          const _SectionHeader(title: 'Cleaning'),
          statusAsync.when(
            loading: () => const GlassCard(child: LinearProgressIndicator()),
            error: (Object _, StackTrace _) => const SizedBox.shrink(),
            data: (RobotStatus status) => _CarpetAndVolumeCard(status: status),
          ),
          const SizedBox(height: AppSpacing.lg),
          const _SectionHeader(title: 'Appearance'),
          GlassCard(
            child: RadioGroup<ThemeMode>(
              groupValue: themeMode,
              onChanged: (ThemeMode? mode) => ref.read(themeModeProvider.notifier).setThemeMode(mode!),
              child: const Column(
                children: [
                  RadioListTile<ThemeMode>(
                    contentPadding: EdgeInsets.zero,
                    title: Text('System Default'),
                    value: ThemeMode.system,
                  ),
                  RadioListTile<ThemeMode>(
                    contentPadding: EdgeInsets.zero,
                    title: Text('Light'),
                    value: ThemeMode.light,
                  ),
                  RadioListTile<ThemeMode>(
                    contentPadding: EdgeInsets.zero,
                    title: Text('Dark'),
                    value: ThemeMode.dark,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          const _SectionHeader(title: 'Do Not Disturb'),
          const _DndCard(),
          const SizedBox(height: AppSpacing.lg),
          const _SectionHeader(title: 'Developer'),
          GlassCard(
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Developer Mode'),
              subtitle: const Text('Verbose logging and diagnostic tools'),
              value: _developerMode,
              onChanged: (bool value) {
                setState(() => _developerMode = value);
                ref.read(localStorageServiceProvider).setDeveloperMode(value);
              },
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          const _SectionHeader(title: 'Danger Zone', color: AppColors.danger),
          GlassCard(
            glowColor: AppColors.danger,
            child: Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.restart_alt_rounded, color: AppColors.danger),
                  title: const Text('Factory Reset'),
                  onTap: () => _confirmFactoryReset(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          const _SectionHeader(title: 'Credits'),
          GlassCard(
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.view_in_ar_outlined, color: AppColors.neonCyan),
              title: const Text('3D robot model'),
              subtitle: const Text('"Rob-vac" by darkfrei on Sketchfab, CC-BY 4.0'),
              trailing: const Icon(Icons.open_in_new_rounded, size: 18),
              onTap: () => launchUrl(
                Uri.parse('https://sketchfab.com/3d-models/robot-vacuum-cleaner-rob-vac-7d904c05d4204d19a2940d9d6f21ef8d'),
                mode: LaunchMode.externalApplication,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Center(
            child: Text('BotDyNax v1.0.0', style: theme.textTheme.bodySmall),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmFactoryReset(BuildContext context) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Factory Reset'),
          content: const Text(
            'This will erase all maps, schedules, and settings stored on the robot. This cannot be undone.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Reset', style: TextStyle(color: AppColors.danger)),
            ),
          ],
        );
      },
    );
    if (confirmed == true) {
      await ref.read(robotControllerProvider).factoryReset();
    }
  }
}

class _CarpetAndVolumeCard extends ConsumerStatefulWidget {
  const _CarpetAndVolumeCard({required this.status});

  final RobotStatus status;

  @override
  ConsumerState<_CarpetAndVolumeCard> createState() => _CarpetAndVolumeCardState();
}

class _CarpetAndVolumeCardState extends ConsumerState<_CarpetAndVolumeCard> {
  late CarpetPreference _carpet = widget.status.carpetPreference;
  late double _volume = widget.status.voiceVolume.toDouble();

  @override
  Widget build(BuildContext context) {
    final RobotController controller = ref.read(robotControllerProvider);

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Carpet Handling', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: AppSpacing.xs),
          RadioGroup<CarpetPreference>(
            groupValue: _carpet,
            onChanged: (CarpetPreference? v) {
              if (v == null) return;
              setState(() => _carpet = v);
              controller.setCarpetPreference(v);
            },
            child: const Column(
              children: [
                RadioListTile<CarpetPreference>(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Adaptive'),
                  subtitle: Text('Boost suction automatically on carpet'),
                  value: CarpetPreference.adaptive,
                ),
                RadioListTile<CarpetPreference>(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Avoid'),
                  subtitle: Text('Steer around carpeted areas'),
                  value: CarpetPreference.avoid,
                ),
                RadioListTile<CarpetPreference>(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Ignore'),
                  subtitle: Text('Treat carpet the same as bare floor'),
                  value: CarpetPreference.ignore,
                ),
              ],
            ),
          ),
          const Divider(height: AppSpacing.lg),
          Text('Voice Volume', style: Theme.of(context).textTheme.labelLarge),
          Row(
            children: [
              const Icon(Icons.volume_down_rounded, color: AppColors.textSecondaryDark, size: 18),
              Expanded(
                child: Slider(
                  value: _volume,
                  min: 0,
                  max: 100,
                  divisions: 20,
                  activeColor: AppColors.neonCyan,
                  label: '${_volume.round()}%',
                  onChanged: (double v) => setState(() => _volume = v),
                  onChangeEnd: (double v) => controller.setVolume(v.round()),
                ),
              ),
              const Icon(Icons.volume_up_rounded, color: AppColors.textSecondaryDark, size: 18),
            ],
          ),
        ],
      ),
    );
  }
}

class _DndCard extends ConsumerStatefulWidget {
  const _DndCard();

  @override
  ConsumerState<_DndCard> createState() => _DndCardState();
}

class _DndCardState extends ConsumerState<_DndCard> {
  late final LocalStorageService _storage = ref.read(localStorageServiceProvider);
  late bool _enabled = _storage.dndEnabled;
  late TimeOfDay _start = _minutesToTime(_storage.dndStartMinutes);
  late TimeOfDay _end = _minutesToTime(_storage.dndEndMinutes);

  TimeOfDay _minutesToTime(int minutes) => TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);

  String _formatTime(TimeOfDay t) => t.format(context);

  Future<void> _pickStart() async {
    final TimeOfDay? picked = await showTimePicker(context: context, initialTime: _start);
    if (picked == null) return;
    setState(() => _start = picked);
    await _storage.setDndStartMinutes(picked.hour * 60 + picked.minute);
  }

  Future<void> _pickEnd() async {
    final TimeOfDay? picked = await showTimePicker(context: context, initialTime: _end);
    if (picked == null) return;
    setState(() => _end = picked);
    await _storage.setDndEndMinutes(picked.hour * 60 + picked.minute);
  }

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Do Not Disturb'),
            subtitle: const Text('Mute cleaning-status notifications during this window'),
            activeThumbColor: AppColors.neonCyan,
            value: _enabled,
            onChanged: (bool v) {
              setState(() => _enabled = v);
              _storage.setDndEnabled(v);
            },
          ),
          if (_enabled) ...[
            const Divider(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Start'),
                    subtitle: Text(_formatTime(_start)),
                    onTap: _pickStart,
                  ),
                ),
                Expanded(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('End'),
                    subtitle: Text(_formatTime(_end)),
                    onTap: _pickEnd,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            const Text(
              'Errors still notify you — DND only mutes routine updates like '
              '"cleaning started/completed". This robot has no data point for '
              'muting its own voice prompts or pausing auto-emptying, so those '
              'still happen on the robot\'s own schedule during this window.',
              style: TextStyle(fontSize: 11.5, color: Colors.white38),
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.color});

  final String title;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(color: color),
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: theme.textTheme.bodyMedium),
          Text(value, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

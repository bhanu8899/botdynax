import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/routing/app_routes.dart';
import '../../core/storage/local_storage_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/glass_card.dart';
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

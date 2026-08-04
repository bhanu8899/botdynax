import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/glass_card.dart';
import '../providers/auth_providers.dart';
import '../providers/cloud_providers.dart';

/// Live view of every data point the robot reports, plus a running log of
/// changes.
///
/// Purpose: the robot's `total_error` fault numbers have no published
/// meaning — the number-to-text mapping lives in the vendor's panel
/// translations, not in any API. The only way to label them correctly is
/// to trigger a condition on the real machine and read the number back.
/// This screen makes that possible from the phone, next to the robot,
/// rather than needing a terminal.
final FutureProviderFamily<List<Map<String, dynamic>>, String> rawDpProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((Ref ref, String robotId) async {
  final Dio dio = ref.watch(apiClientProvider).dio;
  final Response<List<dynamic>> response =
      await dio.get<List<dynamic>>('/tuya/robots/$robotId/status');
  return (response.data ?? const []).cast<Map<String, dynamic>>();
});

/// Decodes `total_error` — hex, one byte per active fault, `00` = clear.
/// Tuya delivers the raw bytes base64-encoded.
List<int> decodeFaultBytes(String? base64Value) {
  if (base64Value == null || base64Value.isEmpty) return const [];
  try {
    return base64Decode(base64Value).where((int b) => b != 0).toList();
  } on FormatException {
    return const [];
  }
}

class DiagnosticsScreen extends ConsumerWidget {
  const DiagnosticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<String?> robotIdAsync = ref.watch(backendRobotIdProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Live Diagnostics')),
      body: robotIdAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace _) => Center(child: Text('Unable to sync robot.\n$error')),
        data: (String? robotId) =>
            robotId == null ? const Center(child: Text('Connect a robot first.')) : _Body(robotId: robotId),
      ),
    );
  }
}

class _Body extends ConsumerStatefulWidget {
  const _Body({required this.robotId});

  final String robotId;

  @override
  ConsumerState<_Body> createState() => _BodyState();
}

class _ChangeEntry {
  _ChangeEntry({required this.time, required this.code, required this.from, required this.to});

  final DateTime time;
  final String code;
  final String from;
  final String to;
}

class _BodyState extends ConsumerState<_Body> {
  Timer? _timer;
  final Map<String, String> _previous = <String, String>{};
  final List<_ChangeEntry> _changes = <_ChangeEntry>[];
  bool _seededBaseline = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (mounted) ref.invalidate(rawDpProvider(widget.robotId));
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// Records transitions so a fault that appears and clears again while
  /// you're walking back to the phone is still visible afterwards.
  void _recordChanges(List<Map<String, dynamic>> points) {
    for (final Map<String, dynamic> point in points) {
      final String code = point['code'] as String;
      final String value = jsonEncode(point['value']);
      final String? old = _previous[code];
      if (old == value) continue;
      _previous[code] = value;
      if (!_seededBaseline || old == null) continue;
      _changes.insert(0, _ChangeEntry(time: DateTime.now(), code: code, from: old, to: value));
    }
    _seededBaseline = true;
    if (_changes.length > 60) _changes.removeRange(60, _changes.length);
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<Map<String, dynamic>>> dpAsync = ref.watch(rawDpProvider(widget.robotId));

    return dpAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (Object error, StackTrace _) => Center(child: Text('Failed to read data points.\n$error')),
      data: (List<Map<String, dynamic>> points) {
        _recordChanges(points);

        final Map<String, dynamic> byCode = <String, dynamic>{
          for (final Map<String, dynamic> p in points) p['code'] as String: p['value'],
        };
        final String? rawError = byCode['total_error'] as String?;
        final List<int> faults = decodeFaultBytes(rawError);

        return ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            _FaultCard(faults: faults, rawValue: rawError),
            const SizedBox(height: AppSpacing.md),
            Text('Recent changes', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            GlassCard(
              child: _changes.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
                      child: Text(
                        'Watching… trigger something on the robot and the change will appear here.',
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    )
                  : Column(
                      children: [
                        for (final _ChangeEntry c in _changes.take(12))
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  width: 60,
                                  child: Text(
                                    c.time.toIso8601String().substring(11, 19),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.white38,
                                      fontFeatures: [FontFeature.tabularFigures()],
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    '${c.code}: ${c.from} → ${c.to}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: c.code == 'total_error' ? AppColors.danger : Colors.white70,
                                      fontWeight:
                                          c.code == 'total_error' ? FontWeight.w700 : FontWeight.normal,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('All data points (${points.length})',
                    style: Theme.of(context).textTheme.titleMedium),
                TextButton.icon(
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  label: const Text('Copy'),
                  onPressed: () {
                    final String dump = points
                        .map((Map<String, dynamic> p) => '${p['code']} = ${jsonEncode(p['value'])}')
                        .join('\n');
                    Clipboard.setData(ClipboardData(text: dump));
                    ScaffoldMessenger.of(context)
                        .showSnackBar(const SnackBar(content: Text('Copied all data points')));
                  },
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xxs),
            GlassCard(
              child: Column(
                children: [
                  for (final Map<String, dynamic> p in points)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 5,
                            child: Text(
                              p['code'] as String,
                              style: const TextStyle(fontSize: 12, color: Colors.white70),
                            ),
                          ),
                          Expanded(
                            flex: 4,
                            child: Text(
                              jsonEncode(p['value']),
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _FaultCard extends StatelessWidget {
  const _FaultCard({required this.faults, required this.rawValue});

  final List<int> faults;
  final String? rawValue;

  @override
  Widget build(BuildContext context) {
    final bool hasFault = faults.isNotEmpty;
    return GlassCard(
      glowColor: hasFault ? AppColors.danger : AppColors.neonCyan,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                hasFault ? Icons.warning_amber_rounded : Icons.check_circle_outline_rounded,
                color: hasFault ? AppColors.danger : AppColors.neonCyan,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                hasFault ? 'ACTIVE FAULT' : 'No faults',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: hasFault ? AppColors.danger : AppColors.neonCyan,
                    ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (hasFault)
            Text(
              faults.join(', '),
              style: const TextStyle(
                fontSize: 52,
                height: 1.05,
                fontWeight: FontWeight.w800,
                color: AppColors.danger,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            )
          else
            const Text(
              'Trigger something on the robot — the fault number will appear here.',
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            'total_error = ${rawValue ?? "—"}'
            '${hasFault ? "   (hex ${faults.map((int f) => f.toRadixString(16).padLeft(2, "0")).join()})" : ""}',
            style: const TextStyle(fontSize: 11, color: Colors.white38),
          ),
        ],
      ),
    );
  }
}

import 'package:hive_flutter/hive_flutter.dart';

/// General-purpose local key/value store for non-sensitive app preferences
/// (auth tokens live in [SecureTokenStorage] instead).
class LocalStorageService {
  static const String _boxName = 'app_prefs';
  static const String _hasSeenOnboardingKey = 'has_seen_onboarding';
  static const String _themeModeKey = 'theme_mode';
  static const String _developerModeKey = 'developer_mode';
  static const String _dndEnabledKey = 'dnd_enabled';
  static const String _dndStartMinutesKey = 'dnd_start_minutes';
  static const String _dndEndMinutesKey = 'dnd_end_minutes';

  Box<dynamic>? _box;

  Future<void> init() async {
    _box = await Hive.openBox<dynamic>(_boxName);
  }

  Box<dynamic> get _requireBox {
    final box = _box;
    if (box == null) {
      throw StateError('LocalStorageService.init() must be called before use');
    }
    return box;
  }

  bool get hasSeenOnboarding => _requireBox.get(_hasSeenOnboardingKey, defaultValue: false) as bool;

  Future<void> setHasSeenOnboarding(bool value) => _requireBox.put(_hasSeenOnboardingKey, value);

  /// One of "system", "light", "dark".
  String get themeModeName => _requireBox.get(_themeModeKey, defaultValue: 'system') as String;

  Future<void> setThemeModeName(String value) => _requireBox.put(_themeModeKey, value);

  bool get developerMode => _requireBox.get(_developerModeKey, defaultValue: false) as bool;

  Future<void> setDeveloperMode(bool value) => _requireBox.put(_developerModeKey, value);

  /// Do Not Disturb has no matching Tuya data point on this device — it's
  /// implemented purely as in-app suppression of the event banner, not a
  /// robot-side setting. This does NOT silence the robot's own voice
  /// prompts or pause auto-dust-collection during the window, since
  /// neither is achievable without a background scheduler actually
  /// issuing commands at the window boundaries — not implemented.
  bool get dndEnabled => _requireBox.get(_dndEnabledKey, defaultValue: false) as bool;

  Future<void> setDndEnabled(bool value) => _requireBox.put(_dndEnabledKey, value);

  /// Minutes since midnight, local time.
  int get dndStartMinutes => _requireBox.get(_dndStartMinutesKey, defaultValue: 22 * 60) as int;

  Future<void> setDndStartMinutes(int value) => _requireBox.put(_dndStartMinutesKey, value);

  int get dndEndMinutes => _requireBox.get(_dndEndMinutesKey, defaultValue: 7 * 60) as int;

  Future<void> setDndEndMinutes(int value) => _requireBox.put(_dndEndMinutesKey, value);

  bool get isWithinDndWindow {
    if (!dndEnabled) return false;
    final DateTime now = DateTime.now();
    final int nowMinutes = now.hour * 60 + now.minute;
    final int start = dndStartMinutes;
    final int end = dndEndMinutes;
    // Window can wrap past midnight (e.g. 22:00 -> 07:00).
    if (start <= end) {
      return nowMinutes >= start && nowMinutes < end;
    }
    return nowMinutes >= start || nowMinutes < end;
  }
}

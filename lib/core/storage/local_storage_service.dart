import 'package:hive_flutter/hive_flutter.dart';

/// General-purpose local key/value store for non-sensitive app preferences
/// (auth tokens live in [SecureTokenStorage] instead).
class LocalStorageService {
  static const String _boxName = 'app_prefs';
  static const String _hasSeenOnboardingKey = 'has_seen_onboarding';
  static const String _themeModeKey = 'theme_mode';
  static const String _developerModeKey = 'developer_mode';

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
}

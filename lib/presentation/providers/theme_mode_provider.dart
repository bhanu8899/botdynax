import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage/local_storage_provider.dart';

final NotifierProvider<ThemeModeController, ThemeMode> themeModeProvider =
    NotifierProvider<ThemeModeController, ThemeMode>(ThemeModeController.new);

class ThemeModeController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    final String name = ref.read(localStorageServiceProvider).themeModeName;
    return _fromName(name);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    await ref.read(localStorageServiceProvider).setThemeModeName(mode.name);
  }

  ThemeMode _fromName(String name) => switch (name) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
}

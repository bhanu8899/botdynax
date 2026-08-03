import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_text_styles.dart';

/// BotDyNax Material 3 theme definitions. Dark theme is the primary,
/// flagship experience; light theme mirrors it with inverted surfaces.
abstract final class AppTheme {
  static ThemeData get dark {
    const ColorScheme scheme = ColorScheme.dark(
      brightness: Brightness.dark,
      primary: AppColors.neonCyan,
      onPrimary: Color(0xFF002B26),
      secondary: AppColors.neonViolet,
      onSecondary: Colors.white,
      surface: AppColors.darkSurface,
      onSurface: AppColors.textPrimaryDark,
      error: AppColors.danger,
      onError: Colors.white,
      outline: AppColors.glassBorderDark,
    );

    return _base(
      scheme: scheme,
      scaffoldBg: AppColors.darkBg,
      textPrimary: AppColors.textPrimaryDark,
      textSecondary: AppColors.textSecondaryDark,
      cardColor: AppColors.darkSurface,
    );
  }

  static ThemeData get light {
    const ColorScheme scheme = ColorScheme.light(
      brightness: Brightness.light,
      primary: Color(0xFF0E9E86),
      onPrimary: Colors.white,
      secondary: AppColors.neonViolet,
      onSecondary: Colors.white,
      surface: AppColors.lightSurface,
      onSurface: AppColors.textPrimaryLight,
      error: AppColors.danger,
      onError: Colors.white,
      outline: AppColors.glassBorderLight,
    );

    return _base(
      scheme: scheme,
      scaffoldBg: AppColors.lightBg,
      textPrimary: AppColors.textPrimaryLight,
      textSecondary: AppColors.textSecondaryLight,
      cardColor: AppColors.lightSurface,
    );
  }

  static ThemeData _base({
    required ColorScheme scheme,
    required Color scaffoldBg,
    required Color textPrimary,
    required Color textSecondary,
    required Color cardColor,
  }) {
    final TextTheme textTheme = AppTextStyles.textTheme(textPrimary, textSecondary);

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffoldBg,
      brightness: scheme.brightness,
      textTheme: textTheme,
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.headlineSmall,
        iconTheme: IconThemeData(color: textPrimary),
      ),
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      dividerTheme: DividerThemeData(color: scheme.outline, thickness: 1, space: 1),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: cardColor,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: cardColor,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: textPrimary),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titleTextStyle: textTheme.headlineSmall,
        contentTextStyle: textTheme.bodyMedium,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}

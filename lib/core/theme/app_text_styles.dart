import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// BotDyNax typography: Sora for display/headline (geometric, technical),
/// Inter for body/label (neutral, highly legible at small sizes).
abstract final class AppTextStyles {
  static TextTheme textTheme(Color primary, Color secondary) {
    final TextStyle sora = GoogleFonts.sora(color: primary);
    final TextStyle inter = GoogleFonts.inter(color: primary);
    final TextStyle interSecondary = GoogleFonts.inter(color: secondary);

    return TextTheme(
      displayLarge: sora.copyWith(
        fontSize: 48,
        fontWeight: FontWeight.w700,
        letterSpacing: -1.0,
        height: 1.05,
      ),
      displayMedium: sora.copyWith(
        fontSize: 36,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        height: 1.1,
      ),
      displaySmall: sora.copyWith(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.3,
        height: 1.15,
      ),
      headlineLarge: sora.copyWith(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
      ),
      headlineMedium: sora.copyWith(fontSize: 20, fontWeight: FontWeight.w600),
      headlineSmall: sora.copyWith(fontSize: 18, fontWeight: FontWeight.w600),
      titleLarge: inter.copyWith(fontSize: 18, fontWeight: FontWeight.w600),
      titleMedium: inter.copyWith(fontSize: 16, fontWeight: FontWeight.w600),
      titleSmall: inter.copyWith(fontSize: 14, fontWeight: FontWeight.w600),
      bodyLarge: inter.copyWith(fontSize: 16, fontWeight: FontWeight.w400, height: 1.4),
      bodyMedium: interSecondary.copyWith(fontSize: 14, fontWeight: FontWeight.w400, height: 1.4),
      bodySmall: interSecondary.copyWith(fontSize: 12, fontWeight: FontWeight.w400, height: 1.3),
      labelLarge: inter.copyWith(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.1),
      labelMedium: interSecondary.copyWith(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.2),
      labelSmall: interSecondary.copyWith(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.3),
    );
  }
}

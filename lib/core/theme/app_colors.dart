import 'package:flutter/material.dart';

/// BotDyNax brand palette. Dark-first, glassmorphic, neon-accented.
abstract final class AppColors {
  // Backgrounds
  static const Color darkBg = Color(0xFF0A0D14);
  static const Color darkBgElevated = Color(0xFF11151F);
  static const Color darkSurface = Color(0xFF161B26);
  static const Color darkSurfaceHigh = Color(0xFF1D2330);

  static const Color lightBg = Color(0xFFF4F6FB);
  static const Color lightBgElevated = Color(0xFFFFFFFF);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceHigh = Color(0xFFEDF0F7);

  // Brand neon accents
  static const Color neonCyan = Color(0xFF22E6C6);
  static const Color neonViolet = Color(0xFF7C5CFF);
  static const Color neonBlue = Color(0xFF3D8BFF);

  // Semantic
  static const Color success = Color(0xFF34D399);
  static const Color warning = Color(0xFFFFB020);
  static const Color danger = Color(0xFFFF5470);
  static const Color info = Color(0xFF3D8BFF);

  // Text - dark theme
  static const Color textPrimaryDark = Color(0xFFF2F4FA);
  static const Color textSecondaryDark = Color(0xFFA6ADC2);
  static const Color textTertiaryDark = Color(0xFF6B7285);

  // Text - light theme
  static const Color textPrimaryLight = Color(0xFF12141C);
  static const Color textSecondaryLight = Color(0xFF565D70);
  static const Color textTertiaryLight = Color(0xFF8B91A3);

  // Glass
  static const Color glassFillDark = Color(0x14FFFFFF);
  static const Color glassBorderDark = Color(0x26FFFFFF);
  static const Color glassFillLight = Color(0xB3FFFFFF);
  static const Color glassBorderLight = Color(0x1F12141C);

  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [neonCyan, neonViolet],
  );

  static const LinearGradient brandGradientSubtle = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0x3322E6C6), Color(0x337C5CFF)],
  );

  static RadialGradient glowGradient(Color color, {double opacity = 0.35}) {
    return RadialGradient(
      colors: [color.withValues(alpha: opacity), color.withValues(alpha: 0)],
    );
  }
}

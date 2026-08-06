import 'package:flutter/material.dart';

/// The real BotDyNax wordmark, picking the black-on-transparent or
/// white-on-transparent PNG variant to match the current theme brightness
/// so it stays legible in both light and dark mode.
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.height = 40});

  final double height;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Image.asset(
      isDark ? 'assets/images/logo_white.png' : 'assets/images/logo_black.png',
      height: height,
      fit: BoxFit.contain,
    );
  }
}

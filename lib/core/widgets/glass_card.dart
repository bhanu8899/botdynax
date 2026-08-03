import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// A frosted-glass floating panel, the primary surface primitive across
/// BotDyNax screens (status cards, control sheets, modals).
class GlassCard extends StatelessWidget {
  const GlassCard({
    required this.child,
    super.key,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.borderRadius = AppSpacing.md * 1.5,
    this.blurSigma = 24,
    this.onTap,
    this.glowColor,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final double blurSigma;
  final VoidCallback? onTap;
  final Color? glowColor;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color fill = isDark ? AppColors.glassFillDark : AppColors.glassFillLight;
    final Color border = isDark ? AppColors.glassBorderDark : AppColors.glassBorderLight;
    final BorderRadius radius = BorderRadius.circular(borderRadius);

    Widget card = ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: fill,
            borderRadius: radius,
            border: Border.all(color: border, width: 1),
          ),
          child: child,
        ),
      ),
    );

    if (glowColor != null) {
      card = DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: [
            BoxShadow(
              color: glowColor!.withValues(alpha: 0.25),
              blurRadius: 32,
              spreadRadius: -8,
            ),
          ],
        ),
        child: card,
      );
    }

    if (onTap == null) return card;

    return Material(
      color: Colors.transparent,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: card,
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Primary call-to-action button: brand gradient fill, used for the single
/// most important action on a screen (Start Cleaning, Continue, Confirm).
class BdPrimaryButton extends StatelessWidget {
  const BdPrimaryButton({
    required this.label,
    required this.onPressed,
    super.key,
    this.icon,
    this.expand = true,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expand;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final bool disabled = onPressed == null || isLoading;

    final Widget content = isLoading
        ? const SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20, color: Colors.white),
                const SizedBox(width: AppSpacing.xs),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: Colors.white,
                        fontSize: 15,
                      ),
                ),
              ),
            ],
          );

    return Opacity(
      opacity: disabled && !isLoading ? 0.5 : 1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: AppColors.brandGradient,
          borderRadius: BorderRadius.circular(AppRadii.pill),
          boxShadow: [
            BoxShadow(
              color: AppColors.neonCyan.withValues(alpha: 0.28),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadii.pill),
            onTap: disabled ? null : onPressed,
            child: Container(
              width: expand ? double.infinity : null,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm + 2),
              alignment: Alignment.center,
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}

/// Secondary action button: outlined glass style for lower-emphasis actions.
class BdSecondaryButton extends StatelessWidget {
  const BdSecondaryButton({
    required this.label,
    required this.onPressed,
    super.key,
    this.icon,
    this.expand = true,
    this.dense = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expand;

  /// Tighter padding and a smaller label, for buttons sharing a row three
  /// or four across. Without this the default padding eats the slot and
  /// the label ellipsises down to "Pre…" / "Sta…".
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color textColor = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final Color borderColor = isDark ? AppColors.glassBorderDark : AppColors.glassBorderLight;

    return SizedBox(
      width: expand ? double.infinity : null,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: textColor,
          side: BorderSide(color: borderColor, width: 1.2),
          padding: EdgeInsets.symmetric(
            horizontal: dense ? AppSpacing.xs : AppSpacing.lg,
            vertical: AppSpacing.sm + 2,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.pill)),
        ),
        // The label is Flexible + ellipsised rather than laid out at its
        // intrinsic width: with a long label ("Return to Dock") sharing a
        // row with icon buttons, the icon + text pair could exceed the
        // Expanded slot and throw a RenderFlex overflow. Shrinking the
        // text is the graceful failure here; overflowing isn't.
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: dense ? 17 : 20, color: textColor),
              SizedBox(width: dense ? 4 : AppSpacing.xs),
            ],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: textColor,
                      fontSize: dense ? 12.5 : null,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact icon-only action button used in floating control clusters.
class BdIconButton extends StatelessWidget {
  const BdIconButton({
    required this.icon,
    required this.onPressed,
    super.key,
    this.size = 52,
    this.active = false,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final double size;
  final bool active;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color fill = active
        ? AppColors.neonCyan.withValues(alpha: 0.18)
        : (isDark ? AppColors.glassFillDark : AppColors.glassFillLight);
    final Color iconColor = active
        ? AppColors.neonCyan
        : (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight);
    final Color borderColor = active
        ? AppColors.neonCyan.withValues(alpha: 0.5)
        : (isDark ? AppColors.glassBorderDark : AppColors.glassBorderLight);

    final Widget button = Material(
      color: fill,
      shape: CircleBorder(side: BorderSide(color: borderColor, width: 1.2)),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: SizedBox(
          height: size,
          width: size,
          child: Icon(icon, color: iconColor, size: size * 0.42),
        ),
      ),
    );

    if (tooltip == null) return button;
    return Tooltip(message: tooltip!, child: button);
  }
}

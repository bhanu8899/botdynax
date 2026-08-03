import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Circular progress ring used for battery, cleaning progress, and
/// consumable life indicators. Animates smoothly between value changes.
class AnimatedProgressRing extends StatelessWidget {
  const AnimatedProgressRing({
    required this.value,
    super.key,
    this.size = 96,
    this.strokeWidth = 8,
    this.color = AppColors.neonCyan,
    this.trackColor,
    this.center,
    this.duration = const Duration(milliseconds: 600),
  });

  /// Progress in the range [0, 1].
  final double value;
  final double size;
  final double strokeWidth;
  final Color color;
  final Color? trackColor;
  final Widget? center;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color track = trackColor ??
        (isDark ? AppColors.darkSurfaceHigh : AppColors.lightSurfaceHigh);

    return SizedBox(
      height: size,
      width: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: value.clamp(0, 1)),
            duration: duration,
            curve: Curves.easeOutCubic,
            builder: (BuildContext context, double animatedValue, Widget? _) {
              return CustomPaint(
                size: Size(size, size),
                painter: _RingPainter(
                  value: animatedValue,
                  color: color,
                  trackColor: track,
                  strokeWidth: strokeWidth,
                ),
              );
            },
          ),
          if (center != null) center!,
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.value,
    required this.color,
    required this.trackColor,
    required this.strokeWidth,
  });

  final double value;
  final Color color;
  final Color trackColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = size.center(Offset.zero);
    final double radius = (math.min(size.width, size.height) - strokeWidth) / 2;

    final Paint trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final Paint progressPaint = Paint()
      ..shader = SweepGradient(
        startAngle: -math.pi / 2,
        endAngle: 3 * math.pi / 2,
        colors: [color.withValues(alpha: 0.5), color],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    const double startAngle = -math.pi / 2;
    final double sweepAngle = 2 * math.pi * value;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) {
    return oldDelegate.value != value ||
        oldDelegate.color != color ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../domain/entities/robot_enums.dart';

/// An original, abstract top-down rendering of a BotDyNax vacuum — not a
/// photo or 3D scan of any real product, just a stylized disc with a
/// sensor bump, side-brush arcs, and a brand-gradient glow that intensifies
/// while the robot is active.
class RobotIllustration extends StatefulWidget {
  const RobotIllustration({required this.activity, super.key, this.size = 220});

  final ActivityState activity;
  final double size;

  @override
  State<RobotIllustration> createState() => _RobotIllustrationState();
}

class _RobotIllustrationState extends State<RobotIllustration> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _isActive => widget.activity == ActivityState.cleaning;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.size,
      width: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (BuildContext context, Widget? _) {
          return CustomPaint(
            size: Size(widget.size, widget.size),
            painter: _RobotPainter(
              rotation: _isActive ? _controller.value * 2 * math.pi : 0,
              glowPulse: _controller.value,
              isCharging: widget.activity == ActivityState.docked || widget.activity == ActivityState.charging,
              isActive: _isActive,
            ),
          );
        },
      ),
    );
  }
}

class _RobotPainter extends CustomPainter {
  const _RobotPainter({
    required this.rotation,
    required this.glowPulse,
    required this.isCharging,
    required this.isActive,
  });

  final double rotation;
  final double glowPulse;
  final bool isCharging;
  final bool isActive;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = size.center(Offset.zero);
    final double radius = size.shortestSide / 2;

    // Ambient glow.
    final double glowOpacity = isActive ? 0.28 + 0.1 * math.sin(glowPulse * 2 * math.pi) : 0.16;
    final Paint glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [AppColors.neonCyan.withValues(alpha: glowOpacity), AppColors.neonCyan.withValues(alpha: 0)],
      ).createShader(Rect.fromCircle(center: center, radius: radius * 1.15));
    canvas.drawCircle(center, radius * 1.15, glowPaint);

    // Body.
    final Paint bodyPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF232A38), Color(0xFF14181F)],
      ).createShader(Rect.fromCircle(center: center, radius: radius * 0.92));
    canvas.drawCircle(center, radius * 0.92, bodyPaint);

    // Brand-gradient bezel ring.
    final Paint bezelPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.045
      ..shader = SweepGradient(
        colors: const [AppColors.neonCyan, AppColors.neonViolet, AppColors.neonCyan],
        transform: GradientRotation(rotation),
      ).createShader(Rect.fromCircle(center: center, radius: radius * 0.92));
    canvas.drawCircle(center, radius * 0.92, bezelPaint);

    // Sensor bump.
    final Offset bumpCenter = center + Offset(0, -radius * 0.55);
    final Paint bumpPaint = Paint()..color = const Color(0xFF2E3646);
    canvas.drawCircle(bumpCenter, radius * 0.16, bumpPaint);
    final Paint bumpRingPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.02
      ..color = AppColors.neonCyan.withValues(alpha: isActive ? 0.9 : 0.4);
    canvas.drawCircle(bumpCenter, radius * 0.16, bumpRingPaint);

    // Side brush arcs (bottom-left / bottom-right).
    final Paint brushPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.05
      ..strokeCap = StrokeCap.round
      ..color = AppColors.neonViolet.withValues(alpha: 0.7);

    final double brushSpin = isActive ? rotation * 3 : 0;
    for (final double sign in [-1.0, 1.0]) {
      final Offset brushCenter = center + Offset(sign * radius * 0.78, radius * 0.55);
      canvas.drawArc(
        Rect.fromCircle(center: brushCenter, radius: radius * 0.22),
        brushSpin,
        4.6,
        false,
        brushPaint,
      );
    }

    // Charging indicator.
    if (isCharging) {
      final TextPainter tp = TextPainter(
        text: TextSpan(
          text: '⚡',
          style: TextStyle(fontSize: radius * 0.4, color: AppColors.warning),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant _RobotPainter oldDelegate) {
    return oldDelegate.rotation != rotation ||
        oldDelegate.glowPulse != glowPulse ||
        oldDelegate.isCharging != isCharging ||
        oldDelegate.isActive != isActive;
  }
}

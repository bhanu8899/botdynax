import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../domain/entities/robot_enums.dart';

/// An original, abstract top-down rendering of a BotDyNax vacuum — not a
/// photo or 3D scan of any real product, just a stylized disc with a
/// sensor bump, side-brush arcs, and a brand-gradient glow. Every visual
/// state below (cleaning motion, docking approach, charge pulse, error
/// jitter) is driven purely by [activity] — the same [ActivityState] the
/// rest of the app reads off the robot's real decoded Tuya status — never
/// by literal position/telemetry we don't have for this device.
class RobotIllustration extends StatefulWidget {
  const RobotIllustration({required this.activity, super.key, this.size = 220});

  final ActivityState activity;
  final double size;

  @override
  State<RobotIllustration> createState() => _RobotIllustrationState();
}

class _RobotIllustrationState extends State<RobotIllustration> with TickerProviderStateMixin {
  late final AnimationController _loopController;
  late final AnimationController _transitionController;
  late _StateParams _fromParams;
  late _StateParams _toParams;

  @override
  void initState() {
    super.initState();
    _loopController = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();
    _toParams = _StateParams.forActivity(widget.activity);
    _fromParams = _toParams;
    _transitionController = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))
      ..value = 1.0;
  }

  @override
  void didUpdateWidget(covariant RobotIllustration oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activity != widget.activity) {
      final double eased = Curves.easeInOutCubic.transform(_transitionController.value);
      _fromParams = _StateParams.lerp(_fromParams, _toParams, eased);
      _toParams = _StateParams.forActivity(widget.activity);
      _transitionController
        ..value = 0
        ..forward();
    }
  }

  @override
  void dispose() {
    _loopController.dispose();
    _transitionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.size,
      width: widget.size,
      child: AnimatedBuilder(
        animation: Listenable.merge([_loopController, _transitionController]),
        builder: (BuildContext context, Widget? _) {
          final _StateParams params = _StateParams.lerp(
            _fromParams,
            _toParams,
            Curves.easeInOutCubic.transform(_transitionController.value),
          );
          return CustomPaint(
            size: Size(widget.size, widget.size),
            painter: _RobotScenePainter(params: params, loopPhase: _loopController.value),
          );
        },
      ),
    );
  }
}

/// Blended visual parameters for one point in time — either a fixed
/// per-[ActivityState] target, or an eased interpolation between two of
/// them while transitioning.
class _StateParams {
  const _StateParams({
    required this.dockOpacity,
    required this.approachAmount,
    required this.motionAmount,
    required this.brushSpin,
    required this.chargeGlow,
    required this.errorShake,
    required this.arrowOpacity,
    required this.glowColor,
  });

  /// Visibility of the charging-dock glyph beneath the robot.
  final double dockOpacity;

  /// 0 = floating center of the canvas, 1 = seated down on the dock.
  final double approachAmount;

  /// Amplitude of the perpetual wander/drift motion (cleaning/returning).
  final double motionAmount;

  /// 0 = brushes stationary, 1 = full spin speed.
  final double brushSpin;

  /// Intensity of the charging pulse + bolt glyph.
  final double chargeGlow;

  /// Amplitude of the rapid error jitter.
  final double errorShake;

  /// Visibility of the "heading toward dock" chevrons.
  final double arrowOpacity;

  final Color glowColor;

  static _StateParams forActivity(ActivityState activity) {
    return switch (activity) {
      ActivityState.cleaning => const _StateParams(
          dockOpacity: 0,
          approachAmount: 0,
          motionAmount: 1,
          brushSpin: 1,
          chargeGlow: 0,
          errorShake: 0,
          arrowOpacity: 0,
          glowColor: AppColors.neonCyan,
        ),
      ActivityState.paused => const _StateParams(
          dockOpacity: 0,
          approachAmount: 0,
          motionAmount: 0,
          brushSpin: 0,
          chargeGlow: 0,
          errorShake: 0,
          arrowOpacity: 0,
          glowColor: AppColors.warning,
        ),
      ActivityState.returningToDock => const _StateParams(
          dockOpacity: 0.7,
          approachAmount: 0.35,
          motionAmount: 0.5,
          brushSpin: 0,
          chargeGlow: 0,
          errorShake: 0,
          arrowOpacity: 1,
          glowColor: AppColors.neonBlue,
        ),
      ActivityState.docked => const _StateParams(
          dockOpacity: 1,
          approachAmount: 1,
          motionAmount: 0,
          brushSpin: 0,
          chargeGlow: 0.18,
          errorShake: 0,
          arrowOpacity: 0,
          glowColor: AppColors.neonCyan,
        ),
      ActivityState.charging => const _StateParams(
          dockOpacity: 1,
          approachAmount: 1,
          motionAmount: 0,
          brushSpin: 0,
          chargeGlow: 1,
          errorShake: 0,
          arrowOpacity: 0,
          glowColor: AppColors.success,
        ),
      ActivityState.error => const _StateParams(
          dockOpacity: 0,
          approachAmount: 0,
          motionAmount: 0,
          brushSpin: 0,
          chargeGlow: 0,
          errorShake: 1,
          arrowOpacity: 0,
          glowColor: AppColors.danger,
        ),
      ActivityState.idle => const _StateParams(
          dockOpacity: 0,
          approachAmount: 0,
          motionAmount: 0,
          brushSpin: 0,
          chargeGlow: 0,
          errorShake: 0,
          arrowOpacity: 0,
          glowColor: AppColors.neonCyan,
        ),
    };
  }

  static _StateParams lerp(_StateParams a, _StateParams b, double t) {
    return _StateParams(
      dockOpacity: lerpDouble(a.dockOpacity, b.dockOpacity, t)!,
      approachAmount: lerpDouble(a.approachAmount, b.approachAmount, t)!,
      motionAmount: lerpDouble(a.motionAmount, b.motionAmount, t)!,
      brushSpin: lerpDouble(a.brushSpin, b.brushSpin, t)!,
      chargeGlow: lerpDouble(a.chargeGlow, b.chargeGlow, t)!,
      errorShake: lerpDouble(a.errorShake, b.errorShake, t)!,
      arrowOpacity: lerpDouble(a.arrowOpacity, b.arrowOpacity, t)!,
      glowColor: Color.lerp(a.glowColor, b.glowColor, t)!,
    );
  }
}

class _RobotScenePainter extends CustomPainter {
  const _RobotScenePainter({required this.params, required this.loopPhase});

  final _StateParams params;
  final double loopPhase;

  @override
  void paint(Canvas canvas, Size size) {
    final double radius = size.shortestSide / 2 * 0.62;
    final Offset canvasCenter = size.center(Offset.zero);
    final double phaseAngle = loopPhase * 2 * math.pi;

    // Dock sits low in the canvas; the robot floats near the vertical
    // center when off-dock and settles onto the dock as approachAmount→1.
    final Offset dockCenter = Offset(canvasCenter.dx, size.height * 0.78);
    final Offset floatCenter = Offset(canvasCenter.dx, canvasCenter.dy - size.height * 0.04);
    Offset robotCenter = Offset.lerp(floatCenter, dockCenter, params.approachAmount)!;

    // Perpetual wander while cleaning; a gentle drift-toward-dock wobble
    // while returning; a rapid jitter on error. All purely decorative
    // motion keyed off the real activity state, not literal position.
    if (params.motionAmount > 0) {
      robotCenter += Offset(
        math.sin(phaseAngle) * radius * 0.5 * params.motionAmount,
        math.sin(phaseAngle * 1.7) * radius * 0.22 * params.motionAmount,
      );
    }
    if (params.errorShake > 0) {
      robotCenter += Offset(
        math.sin(phaseAngle * 10) * radius * 0.06 * params.errorShake,
        math.cos(phaseAngle * 13) * radius * 0.04 * params.errorShake,
      );
    }

    if (params.dockOpacity > 0.01) {
      _paintDock(canvas, dockCenter, radius, params.dockOpacity);
    }
    if (params.arrowOpacity > 0.01) {
      _paintApproachChevrons(canvas, robotCenter, dockCenter, radius, params.arrowOpacity, phaseAngle);
    }

    _paintRobot(canvas, robotCenter, radius, phaseAngle);
  }

  void _paintDock(Canvas canvas, Offset center, double radius, double opacity) {
    final Rect dockRect = Rect.fromCenter(center: center, width: radius * 2.6, height: radius * 0.9);
    final RRect dockRRect = RRect.fromRectAndRadius(dockRect, Radius.circular(radius * 0.22));

    final Paint dockShadow = Paint()
      ..color = Colors.black.withValues(alpha: 0.35 * opacity)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    canvas.drawRRect(dockRRect.shift(const Offset(0, 6)), dockShadow);

    final Paint dockPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF232A38).withValues(alpha: opacity),
          const Color(0xFF11151F).withValues(alpha: opacity),
        ],
      ).createShader(dockRect);
    canvas.drawRRect(dockRRect, dockPaint);

    final Paint dockEdge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = params.glowColor.withValues(alpha: 0.35 * opacity);
    canvas.drawRRect(dockRRect, dockEdge);

    // Charging pin glyph.
    final Paint pinPaint = Paint()..color = params.glowColor.withValues(alpha: 0.6 * opacity);
    canvas.drawCircle(Offset(center.dx, center.dy - radius * 0.08), radius * 0.06, pinPaint);
  }

  void _paintApproachChevrons(
    Canvas canvas,
    Offset from,
    Offset to,
    double radius,
    double opacity,
    double phaseAngle,
  ) {
    final Offset direction = (to - from);
    final double distance = direction.distance;
    if (distance < 1) return;
    final Offset unit = direction / distance;
    final double travel = (loopPhase) % 1.0;

    for (int i = 0; i < 3; i++) {
      final double t = ((travel + i * 0.33) % 1.0);
      final Offset chevronCenter = from + unit * distance * t;
      final double fade = (math.sin(t * math.pi)).clamp(0.0, 1.0);
      final Paint chevronPaint = Paint()
        ..color = params.glowColor.withValues(alpha: opacity * fade * 0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius * 0.06
        ..strokeCap = StrokeCap.round;
      final double angle = math.atan2(unit.dy, unit.dx);
      canvas.save();
      canvas.translate(chevronCenter.dx, chevronCenter.dy);
      canvas.rotate(angle);
      final Path chevron = Path()
        ..moveTo(-radius * 0.08, -radius * 0.1)
        ..lineTo(radius * 0.08, 0)
        ..lineTo(-radius * 0.08, radius * 0.1);
      canvas.drawPath(chevron, chevronPaint);
      canvas.restore();
    }
  }

  void _paintRobot(Canvas canvas, Offset center, double radius, double phaseAngle) {
    final bool isActive = params.brushSpin > 0.01;

    // Ambient glow.
    final double basePulse = 0.16 + 0.1 * math.sin(phaseAngle);
    final double glowOpacity = (basePulse + params.chargeGlow * 0.25).clamp(0.0, 0.55);
    final Paint glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [params.glowColor.withValues(alpha: glowOpacity), params.glowColor.withValues(alpha: 0)],
      ).createShader(Rect.fromCircle(center: center, radius: radius * 1.15));
    canvas.drawCircle(center, radius * 1.15, glowPaint);

    // Charging pulse rings.
    if (params.chargeGlow > 0.01) {
      final double ringT = loopPhase;
      final Paint ringPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = params.glowColor.withValues(alpha: (1 - ringT) * 0.5 * params.chargeGlow);
      canvas.drawCircle(center, radius * (1.0 + ringT * 0.5), ringPaint);
    }

    // Body.
    final Paint bodyPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF232A38), Color(0xFF14181F)],
      ).createShader(Rect.fromCircle(center: center, radius: radius * 0.92));
    canvas.drawCircle(center, radius * 0.92, bodyPaint);

    // Brand-gradient bezel ring — spins only while actively cleaning.
    final Paint bezelPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.045
      ..shader = SweepGradient(
        colors: [params.glowColor, AppColors.neonViolet, params.glowColor],
        transform: GradientRotation(isActive ? phaseAngle : 0),
      ).createShader(Rect.fromCircle(center: center, radius: radius * 0.92));
    canvas.drawCircle(center, radius * 0.92, bezelPaint);

    // Sensor bump.
    final Offset bumpCenter = center + Offset(0, -radius * 0.55);
    final Paint bumpPaint = Paint()..color = const Color(0xFF2E3646);
    canvas.drawCircle(bumpCenter, radius * 0.16, bumpPaint);
    final Paint bumpRingPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.02
      ..color = params.glowColor.withValues(alpha: isActive ? 0.9 : 0.4);
    canvas.drawCircle(bumpCenter, radius * 0.16, bumpRingPaint);

    // Side brush arcs — spin scales with brushSpin (0 while docked/paused).
    final Paint brushPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.05
      ..strokeCap = StrokeCap.round
      ..color = AppColors.neonViolet.withValues(alpha: 0.4 + 0.4 * params.brushSpin);

    final double brushSpinAngle = phaseAngle * 3 * params.brushSpin;
    for (final double sign in [-1.0, 1.0]) {
      final Offset brushCenter = center + Offset(sign * radius * 0.78, radius * 0.55);
      canvas.drawArc(
        Rect.fromCircle(center: brushCenter, radius: radius * 0.22),
        brushSpinAngle,
        4.6,
        false,
        brushPaint,
      );
    }

    // Charging bolt.
    if (params.chargeGlow > 0.01) {
      final double boltPulse = 0.7 + 0.3 * math.sin(phaseAngle * 2);
      final TextPainter tp = TextPainter(
        text: TextSpan(
          text: '⚡',
          style: TextStyle(
            fontSize: radius * 0.4,
            color: AppColors.warning.withValues(alpha: params.chargeGlow * boltPulse),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant _RobotScenePainter oldDelegate) {
    return oldDelegate.loopPhase != loopPhase || oldDelegate.params != params;
  }
}

import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../domain/entities/robot_enums.dart';
import '../../../domain/entities/robot_status.dart';

/// An original, abstract top-down rendering of a BotDyNax vacuum and its
/// dock — not a photo or 3D scan of any real product, just a stylized disc
/// and base with brand-gradient glow. Every visual state below (cleaning
/// motion, docking approach, charge pulse) is driven purely by
/// [RobotStatus.activity] — the same [ActivityState] the rest of the app
/// reads off the robot's real decoded Tuya status — never by literal
/// position/telemetry we don't have for this device.
///
/// On top of that, five dock/robot sub-components highlight red
/// independently of activity, each driven by one specific empirically
/// confirmed `total_error` fault code (see [RobotStatus]'s
/// `isDustBagMissing`/`isMopPadsRemoved`/`isCleanWaterTankMissing`/
/// `isSewageTankMissing`/`isDustBinMissing` getters) — so a fault shows
/// exactly where it physically is, and any combination can be active at
/// once without affecting the rest of the illustration.
class RobotIllustration extends StatefulWidget {
  const RobotIllustration({required this.status, super.key, this.size = 220});

  final RobotStatus status;
  final double size;

  @override
  State<RobotIllustration> createState() => _RobotIllustrationState();
}

enum _FaultZone { dustBag, waterTank, sewageTank, mopPads, dustBin }

class _RobotIllustrationState extends State<RobotIllustration> with TickerProviderStateMixin {
  late final AnimationController _loopController;
  late final AnimationController _transitionController;
  late _StateParams _fromParams;
  late _StateParams _toParams;

  late final Map<_FaultZone, AnimationController> _faultControllers;

  @override
  void initState() {
    super.initState();
    _loopController = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();
    _toParams = _StateParams.forActivity(widget.status.activity);
    _fromParams = _toParams;
    _transitionController = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))
      ..value = 1.0;

    _faultControllers = {
      for (final _FaultZone zone in _FaultZone.values)
        zone: AnimationController(vsync: this, duration: const Duration(milliseconds: 350)),
    };
    for (final MapEntry<_FaultZone, bool> entry in _currentFaults(widget.status).entries) {
      if (entry.value) _faultControllers[entry.key]!.value = 1.0;
    }
  }

  Map<_FaultZone, bool> _currentFaults(RobotStatus status) => {
        _FaultZone.dustBag: status.isDustBagMissing,
        _FaultZone.waterTank: status.isCleanWaterTankMissing,
        _FaultZone.sewageTank: status.isSewageTankMissing,
        _FaultZone.mopPads: status.isMopPadsRemoved,
        _FaultZone.dustBin: status.isDustBinMissing,
      };

  @override
  void didUpdateWidget(covariant RobotIllustration oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.status.activity != widget.status.activity) {
      final double eased = Curves.easeInOutCubic.transform(_transitionController.value);
      _fromParams = _StateParams.lerp(_fromParams, _toParams, eased);
      _toParams = _StateParams.forActivity(widget.status.activity);
      _transitionController
        ..value = 0
        ..forward();
    }
    _currentFaults(widget.status).forEach((_FaultZone zone, bool active) {
      final AnimationController controller = _faultControllers[zone]!;
      if (active && controller.status != AnimationStatus.forward && controller.value != 1.0) {
        controller.forward();
      } else if (!active && controller.status != AnimationStatus.reverse && controller.value != 0.0) {
        controller.reverse();
      }
    });
  }

  @override
  void dispose() {
    _loopController.dispose();
    _transitionController.dispose();
    for (final AnimationController c in _faultControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.size,
      width: widget.size,
      child: AnimatedBuilder(
        animation: Listenable.merge([
          _loopController,
          _transitionController,
          ..._faultControllers.values,
        ]),
        builder: (BuildContext context, Widget? _) {
          final _StateParams params = _StateParams.lerp(
            _fromParams,
            _toParams,
            Curves.easeInOutCubic.transform(_transitionController.value),
          );
          return CustomPaint(
            size: Size(widget.size, widget.size),
            painter: _RobotScenePainter(
              params: params,
              loopPhase: _loopController.value,
              faultIntensity: {for (final entry in _faultControllers.entries) entry.key: entry.value.value},
            ),
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
  const _RobotScenePainter({required this.params, required this.loopPhase, required this.faultIntensity});

  final _StateParams params;
  final double loopPhase;
  final Map<_FaultZone, double> faultIntensity;

  double _intensity(_FaultZone zone) => faultIntensity[zone] ?? 0.0;

  @override
  void paint(Canvas canvas, Size size) {
    final double radius = size.shortestSide / 2 * 0.62;
    final Offset canvasCenter = size.center(Offset.zero);
    final double phaseAngle = loopPhase * 2 * math.pi;
    // Fast independent blink for fault highlights, decoupled from the
    // slower ambient loop so a fault reads as an alert, not decoration.
    final double blink = 0.55 + 0.45 * math.sin(loopPhase * 2 * math.pi * 4.2);

    // Dock sits low in the canvas; the robot floats near the vertical
    // center when off-dock and settles onto the dock as approachAmount→1.
    final Offset dockCenter = Offset(canvasCenter.dx, size.height * 0.74);
    final Offset floatCenter = Offset(canvasCenter.dx, canvasCenter.dy - size.height * 0.08);
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
      _paintDock(canvas, dockCenter, radius, params.dockOpacity, blink);
    }
    if (params.arrowOpacity > 0.01) {
      _paintApproachChevrons(canvas, robotCenter, dockCenter, radius, params.arrowOpacity, phaseAngle);
    }

    _paintRobot(canvas, robotCenter, radius, phaseAngle, blink);
    _paintLabels(canvas, size, dockCenter, robotCenter, radius, blink);
  }

  void _paintDock(Canvas canvas, Offset center, double radius, double opacity, double blink) {
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

    // Sewage / dirty-water tank — LEFT side of the dock base.
    _paintTankZone(
      canvas,
      center: Offset(center.dx - radius * 0.95, center.dy + radius * 0.05),
      size: Size(radius * 0.55, radius * 0.62),
      radius: radius,
      neutralColor: const Color(0xFF6B5A3F),
      opacity: opacity,
      intensity: _intensity(_FaultZone.sewageTank),
      blink: blink,
    );

    // Clean-water tank — RIGHT side of the dock base.
    _paintTankZone(
      canvas,
      center: Offset(center.dx + radius * 0.95, center.dy + radius * 0.05),
      size: Size(radius * 0.55, radius * 0.62),
      radius: radius,
      neutralColor: AppColors.neonBlue,
      opacity: opacity,
      intensity: _intensity(_FaultZone.waterTank),
      blink: blink,
    );

    // Dust bag canister — standing at the back-center of the dock, behind
    // where the robot seats.
    final Offset bagCenter = Offset(center.dx, center.dy - radius * 0.62);
    final Size bagSize = Size(radius * 0.5, radius * 0.68);
    final double bagIntensity = _intensity(_FaultZone.dustBag);
    final Color bagColor = Color.lerp(const Color(0xFF3A4356), AppColors.danger, bagIntensity * blink)!;
    final RRect bagRRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: bagCenter, width: bagSize.width, height: bagSize.height),
      Radius.circular(bagSize.width * 0.3),
    );
    if (bagIntensity > 0.01) {
      final Paint bagGlow = Paint()
        ..color = AppColors.danger.withValues(alpha: 0.45 * bagIntensity * blink)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
      canvas.drawRRect(bagRRect.inflate(3), bagGlow);
    }
    canvas.drawRRect(bagRRect, Paint()..color = bagColor.withValues(alpha: opacity));
    canvas.drawRRect(
      bagRRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = (bagIntensity > 0.01 ? AppColors.danger : params.glowColor).withValues(alpha: 0.6 * opacity),
    );
  }

  void _paintTankZone(
    Canvas canvas, {
    required Offset center,
    required Size size,
    required double radius,
    required Color neutralColor,
    required double opacity,
    required double intensity,
    required double blink,
  }) {
    final RRect rrect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center, width: size.width, height: size.height),
      Radius.circular(size.width * 0.28),
    );
    final Color fill = Color.lerp(neutralColor, AppColors.danger, intensity * blink)!;
    if (intensity > 0.01) {
      final Paint glow = Paint()
        ..color = AppColors.danger.withValues(alpha: 0.45 * intensity * blink)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
      canvas.drawRRect(rrect.inflate(3), glow);
    }
    canvas.drawRRect(rrect, Paint()..color = fill.withValues(alpha: (0.55 + 0.45 * intensity) * opacity));
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = (intensity > 0.01 ? AppColors.danger : Colors.white).withValues(alpha: 0.5 * opacity),
    );
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

  void _paintRobot(Canvas canvas, Offset center, double radius, double phaseAngle, double blink) {
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

    // Internal dust bin lid — small panel just behind the sensor bump.
    final double binIntensity = _intensity(_FaultZone.dustBin);
    final Offset binCenter = center + Offset(0, -radius * 0.24);
    final RRect binRRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: binCenter, width: radius * 0.34, height: radius * 0.16),
      Radius.circular(radius * 0.04),
    );
    if (binIntensity > 0.01) {
      canvas.drawRRect(
        binRRect.inflate(2),
        Paint()
          ..color = AppColors.danger.withValues(alpha: 0.5 * binIntensity * blink)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
    }
    canvas.drawRRect(
      binRRect,
      Paint()..color = Color.lerp(const Color(0xFF2E3646), AppColors.danger, binIntensity * blink)!,
    );
    canvas.drawRRect(
      binRRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius * 0.015
        ..color = (binIntensity > 0.01 ? AppColors.danger : params.glowColor).withValues(alpha: 0.7),
    );

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

    // Mop pads — two pads peeking out from beneath the front of the body.
    final double mopIntensity = _intensity(_FaultZone.mopPads);
    for (final double sign in [-1.0, 1.0]) {
      final Offset padCenter = center + Offset(sign * radius * 0.32, radius * 0.86);
      final RRect padRRect = RRect.fromRectAndRadius(
        Rect.fromCenter(center: padCenter, width: radius * 0.34, height: radius * 0.2),
        Radius.circular(radius * 0.08),
      );
      if (mopIntensity > 0.01) {
        canvas.drawRRect(
          padRRect.inflate(2.5),
          Paint()
            ..color = AppColors.danger.withValues(alpha: 0.5 * mopIntensity * blink)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
        );
      }
      canvas.drawRRect(
        padRRect,
        Paint()..color = Color.lerp(const Color(0xFF3D4557), AppColors.danger, mopIntensity * blink)!,
      );
      canvas.drawRRect(
        padRRect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = radius * 0.015
          ..color = (mopIntensity > 0.01 ? AppColors.danger : Colors.white).withValues(alpha: 0.5),
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

  void _paintLabels(Canvas canvas, Size size, Offset dockCenter, Offset robotCenter, double radius, double blink) {
    final List<(Offset, String)> active = [
      if (_intensity(_FaultZone.dustBag) > 0.4)
        (Offset(dockCenter.dx, dockCenter.dy - radius * 1.15), 'Dust Bag Missing'),
      if (_intensity(_FaultZone.waterTank) > 0.4)
        (Offset(dockCenter.dx + radius * 0.95, dockCenter.dy + radius * 0.55), 'Water Tank Missing'),
      if (_intensity(_FaultZone.sewageTank) > 0.4)
        (Offset(dockCenter.dx - radius * 0.95, dockCenter.dy + radius * 0.55), 'Sewage Tank Missing'),
      if (_intensity(_FaultZone.mopPads) > 0.4)
        (Offset(robotCenter.dx, robotCenter.dy + radius * 1.1), 'Mop Pads Removed'),
      if (_intensity(_FaultZone.dustBin) > 0.4)
        (Offset(robotCenter.dx + radius * 0.75, robotCenter.dy - radius * 0.24), 'Dust Bin Removed'),
    ];
    for (final (Offset anchor, String label) in active) {
      final TextPainter tp = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: AppColors.danger.withValues(alpha: 0.7 + 0.3 * blink),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: size.width);
      final Offset topLeft = Offset(
        (anchor.dx - tp.width / 2).clamp(0.0, size.width - tp.width),
        anchor.dy.clamp(0.0, size.height - tp.height),
      );
      final RRect bg = RRect.fromRectAndRadius(
        (topLeft & tp.size).inflate(3),
        const Radius.circular(4),
      );
      canvas.drawRRect(bg, Paint()..color = Colors.black.withValues(alpha: 0.55));
      tp.paint(canvas, topLeft);
    }
  }

  @override
  bool shouldRepaint(covariant _RobotScenePainter oldDelegate) {
    return oldDelegate.loopPhase != loopPhase ||
        oldDelegate.params != params ||
        oldDelegate.faultIntensity != faultIntensity;
  }
}

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// A circular drag pad that reports normalized (linear, angular) drive
/// values in [-1, 1] as the knob moves, and snaps back to center (emitting
/// zero) on release — the standard "dead-man's switch" joystick pattern for
/// remote-controlling a vehicle.
class JoystickPad extends StatefulWidget {
  const JoystickPad({required this.onChanged, super.key, this.size = 220});

  final void Function(double linear, double angular) onChanged;
  final double size;

  @override
  State<JoystickPad> createState() => _JoystickPadState();
}

class _JoystickPadState extends State<JoystickPad> {
  Offset _knobOffset = Offset.zero;

  double get _maxRadius => widget.size / 2 - 32;

  void _updateFromLocalPosition(Offset localPosition) {
    final Offset center = Offset(widget.size / 2, widget.size / 2);
    Offset delta = localPosition - center;
    if (delta.distance > _maxRadius) {
      delta = Offset.fromDirection(delta.direction, _maxRadius);
    }
    setState(() => _knobOffset = delta);

    final double angular = (delta.dx / _maxRadius).clamp(-1.0, 1.0);
    final double linear = (-delta.dy / _maxRadius).clamp(-1.0, 1.0);
    widget.onChanged(linear, angular);
  }

  void _reset() {
    setState(() => _knobOffset = Offset.zero);
    widget.onChanged(0, 0);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: (DragStartDetails details) => _updateFromLocalPosition(details.localPosition),
      onPanUpdate: (DragUpdateDetails details) => _updateFromLocalPosition(details.localPosition),
      onPanEnd: (DragEndDetails details) => _reset(),
      onPanCancel: _reset,
      child: SizedBox(
        height: widget.size,
        width: widget.size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.glassFillDark,
                border: Border.all(color: AppColors.glassBorderDark, width: 1.5),
              ),
            ),
            CustomPaint(size: Size(widget.size, widget.size), painter: _DirectionMarksPainter()),
            AnimatedContainer(
              duration: _knobOffset == Offset.zero
                  ? const Duration(milliseconds: 180)
                  : Duration.zero,
              curve: Curves.easeOut,
              transform: Matrix4.translationValues(_knobOffset.dx, _knobOffset.dy, 0),
              height: 56,
              width: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppColors.brandGradient,
                boxShadow: [
                  BoxShadow(color: AppColors.neonCyan.withValues(alpha: 0.5), blurRadius: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DirectionMarksPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = size.center(Offset.zero);
    final Paint paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.25)
      ..strokeWidth = 2;
    const double markLength = 10;

    for (final double angle in [0, 90, 180, 270]) {
      final double radians = angle * 3.1415926535 / 180;
      final Offset outer = center + Offset.fromDirection(radians - 1.5708, size.width / 2 - 6);
      final Offset inner = center + Offset.fromDirection(radians - 1.5708, size.width / 2 - 6 - markLength);
      canvas.drawLine(inner, outer, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DirectionMarksPainter oldDelegate) => false;
}

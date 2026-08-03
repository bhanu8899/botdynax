import 'dart:math' as math;

import 'package:flutter/animation.dart';

import '../../domain/entities/map_data.dart';

/// Interpolates robot position linearly and heading along the shortest
/// angular path, so a robot that turns from 350° to 10° visually sweeps 20°
/// forward instead of spinning the long way around.
class PoseTween extends Tween<Pose> {
  PoseTween({required Pose super.begin, required Pose super.end});

  @override
  Pose lerp(double t) {
    final Pose from = begin!;
    final Pose to = end!;

    final MapPoint position = MapPoint(
      from.position.x + (to.position.x - from.position.x) * t,
      from.position.y + (to.position.y - from.position.y) * t,
    );

    double delta = (to.headingRadians - from.headingRadians) % (2 * math.pi);
    if (delta > math.pi) delta -= 2 * math.pi;
    if (delta < -math.pi) delta += 2 * math.pi;

    return Pose(position: position, headingRadians: from.headingRadians + delta * t);
  }
}

import 'package:equatable/equatable.dart';

import 'robot_enums.dart';

/// Tracks remaining life of a replaceable/maintainable robot part.
class Consumable extends Equatable {
  const Consumable({
    required this.type,
    required this.remainingPercent,
    required this.ratedLifetimeMinutes,
    required this.usedMinutes,
  });

  final ConsumableType type;

  /// 0.0 - 1.0
  final double remainingPercent;
  final int ratedLifetimeMinutes;
  final int usedMinutes;

  bool get needsReplacement => remainingPercent <= 0.1;

  String get label => switch (type) {
        ConsumableType.mainBrush => 'Main Brush',
        ConsumableType.sideBrush => 'Side Brush',
        ConsumableType.filter => 'Filter',
        ConsumableType.mopPad => 'Mop Pad',
        ConsumableType.battery => 'Battery',
        ConsumableType.sensor => 'Sensors',
      };

  Consumable copyWith({
    ConsumableType? type,
    double? remainingPercent,
    int? ratedLifetimeMinutes,
    int? usedMinutes,
  }) {
    return Consumable(
      type: type ?? this.type,
      remainingPercent: remainingPercent ?? this.remainingPercent,
      ratedLifetimeMinutes: ratedLifetimeMinutes ?? this.ratedLifetimeMinutes,
      usedMinutes: usedMinutes ?? this.usedMinutes,
    );
  }

  @override
  List<Object?> get props => [type, remainingPercent, ratedLifetimeMinutes, usedMinutes];
}

import 'package:equatable/equatable.dart';

import 'robot_enums.dart';

/// A recurring or one-off cleaning schedule, persisted server-side so it
/// survives app reinstalls and can (eventually) be pushed to the robot
/// even when the phone is offline.
class CleaningSchedule extends Equatable {
  const CleaningSchedule({
    required this.id,
    required this.label,
    required this.daysOfWeek,
    required this.time,
    required this.mode,
    required this.roomIds,
    required this.vacuumPower,
    required this.waterLevel,
    required this.enabled,
    required this.notify,
  });

  final String id;
  final String label;

  /// CSV of weekday indices (0=Sun..6=Sat), or the literal "DAILY".
  final String daysOfWeek;

  /// 24h "HH:mm".
  final String time;

  final CleaningMode mode;
  final List<String> roomIds;
  final VacuumPower vacuumPower;
  final WaterFlow waterLevel;
  final bool enabled;
  final bool notify;

  List<int> get weekdays {
    if (daysOfWeek == 'DAILY') return const [0, 1, 2, 3, 4, 5, 6];
    return daysOfWeek.split(',').where((s) => s.isNotEmpty).map(int.parse).toList();
  }

  static const List<String> weekdayLabels = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

  String get recurrenceSummary {
    if (daysOfWeek == 'DAILY') return 'Every day';
    final List<int> days = weekdays..sort();
    if (days.length == 7) return 'Every day';
    return days.map((int d) => weekdayLabels[d]).join(', ');
  }

  CleaningSchedule copyWith({
    String? label,
    String? daysOfWeek,
    String? time,
    CleaningMode? mode,
    List<String>? roomIds,
    VacuumPower? vacuumPower,
    WaterFlow? waterLevel,
    bool? enabled,
    bool? notify,
  }) {
    return CleaningSchedule(
      id: id,
      label: label ?? this.label,
      daysOfWeek: daysOfWeek ?? this.daysOfWeek,
      time: time ?? this.time,
      mode: mode ?? this.mode,
      roomIds: roomIds ?? this.roomIds,
      vacuumPower: vacuumPower ?? this.vacuumPower,
      waterLevel: waterLevel ?? this.waterLevel,
      enabled: enabled ?? this.enabled,
      notify: notify ?? this.notify,
    );
  }

  @override
  List<Object?> get props =>
      [id, label, daysOfWeek, time, mode, roomIds, vacuumPower, waterLevel, enabled, notify];
}

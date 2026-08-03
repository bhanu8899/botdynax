import 'package:equatable/equatable.dart';

import 'consumable.dart';
import 'robot_enums.dart';

/// Live signal quality for a wireless link, on a 0-4 bar scale.
class SignalStrength extends Equatable {
  const SignalStrength({required this.bars, required this.rssi});

  const SignalStrength.none() : bars = 0, rssi = -120;

  final int bars;
  final int rssi;

  @override
  List<Object?> get props => [bars, rssi];
}

/// Complete real-time snapshot of a single robot's state, as surfaced by
/// [RobotTransport.receiveStatus]. This is the single source of truth the
/// home dashboard, control panel, and settings screens all render from.
class RobotStatus extends Equatable {
  const RobotStatus({
    required this.robotId,
    required this.name,
    required this.connection,
    required this.activity,
    required this.batteryPercent,
    required this.isCharging,
    required this.vacuumPower,
    required this.waterFlow,
    required this.currentRoom,
    required this.currentTask,
    required this.areaCleanedSqm,
    required this.cleaningElapsed,
    required this.cleaningRemaining,
    required this.wifiSignal,
    required this.bleSignal,
    required this.firmwareVersion,
    required this.waterTankPercent,
    required this.dustBinPercent,
    required this.consumables,
    required this.activeErrors,
    required this.isChildLockOn,
    required this.lastUpdated,
  });

  factory RobotStatus.initial(String robotId, String name) {
    return RobotStatus(
      robotId: robotId,
      name: name,
      connection: RobotConnectionState.disconnected,
      activity: ActivityState.idle,
      batteryPercent: 0,
      isCharging: false,
      vacuumPower: VacuumPower.standard,
      waterFlow: WaterFlow.medium,
      currentRoom: null,
      currentTask: null,
      areaCleanedSqm: 0,
      cleaningElapsed: Duration.zero,
      cleaningRemaining: Duration.zero,
      wifiSignal: const SignalStrength.none(),
      bleSignal: const SignalStrength.none(),
      firmwareVersion: '—',
      waterTankPercent: 0,
      dustBinPercent: 0,
      consumables: const [],
      activeErrors: const [],
      isChildLockOn: false,
      lastUpdated: DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  final String robotId;
  final String name;
  final RobotConnectionState connection;
  final ActivityState activity;

  /// 0.0 - 1.0
  final double batteryPercent;
  final bool isCharging;

  final VacuumPower vacuumPower;
  final WaterFlow waterFlow;

  final String? currentRoom;
  final String? currentTask;
  final double areaCleanedSqm;
  final Duration cleaningElapsed;
  final Duration cleaningRemaining;

  final SignalStrength wifiSignal;
  final SignalStrength bleSignal;
  final String firmwareVersion;

  /// 0.0 - 1.0
  final double waterTankPercent;

  /// 0.0 - 1.0
  final double dustBinPercent;

  final List<Consumable> consumables;
  final List<RobotErrorCode> activeErrors;
  final bool isChildLockOn;
  final DateTime lastUpdated;

  bool get isOnline => connection == RobotConnectionState.connected;
  bool get hasErrors => activeErrors.isNotEmpty;
  bool get isCleaning => activity == ActivityState.cleaning;

  RobotStatus copyWith({
    String? robotId,
    String? name,
    RobotConnectionState? connection,
    ActivityState? activity,
    double? batteryPercent,
    bool? isCharging,
    VacuumPower? vacuumPower,
    WaterFlow? waterFlow,
    String? currentRoom,
    String? currentTask,
    double? areaCleanedSqm,
    Duration? cleaningElapsed,
    Duration? cleaningRemaining,
    SignalStrength? wifiSignal,
    SignalStrength? bleSignal,
    String? firmwareVersion,
    double? waterTankPercent,
    double? dustBinPercent,
    List<Consumable>? consumables,
    List<RobotErrorCode>? activeErrors,
    bool? isChildLockOn,
    DateTime? lastUpdated,
    bool clearCurrentRoom = false,
    bool clearCurrentTask = false,
  }) {
    return RobotStatus(
      robotId: robotId ?? this.robotId,
      name: name ?? this.name,
      connection: connection ?? this.connection,
      activity: activity ?? this.activity,
      batteryPercent: batteryPercent ?? this.batteryPercent,
      isCharging: isCharging ?? this.isCharging,
      vacuumPower: vacuumPower ?? this.vacuumPower,
      waterFlow: waterFlow ?? this.waterFlow,
      currentRoom: clearCurrentRoom ? null : (currentRoom ?? this.currentRoom),
      currentTask: clearCurrentTask ? null : (currentTask ?? this.currentTask),
      areaCleanedSqm: areaCleanedSqm ?? this.areaCleanedSqm,
      cleaningElapsed: cleaningElapsed ?? this.cleaningElapsed,
      cleaningRemaining: cleaningRemaining ?? this.cleaningRemaining,
      wifiSignal: wifiSignal ?? this.wifiSignal,
      bleSignal: bleSignal ?? this.bleSignal,
      firmwareVersion: firmwareVersion ?? this.firmwareVersion,
      waterTankPercent: waterTankPercent ?? this.waterTankPercent,
      dustBinPercent: dustBinPercent ?? this.dustBinPercent,
      consumables: consumables ?? this.consumables,
      activeErrors: activeErrors ?? this.activeErrors,
      isChildLockOn: isChildLockOn ?? this.isChildLockOn,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  @override
  List<Object?> get props => [
        robotId,
        name,
        connection,
        activity,
        batteryPercent,
        isCharging,
        vacuumPower,
        waterFlow,
        currentRoom,
        currentTask,
        areaCleanedSqm,
        cleaningElapsed,
        cleaningRemaining,
        wifiSignal,
        bleSignal,
        firmwareVersion,
        waterTankPercent,
        dustBinPercent,
        consumables,
        activeErrors,
        isChildLockOn,
        lastUpdated,
      ];
}

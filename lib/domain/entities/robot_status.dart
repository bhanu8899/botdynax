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
    required this.isMopAttached,
    this.deviceOnline = true,
    required this.faultCodes,
    required this.faultMessages,
    required this.cleaningType,
    required this.cleaningPasses,
    required this.carpetPreference,
    required this.autoDustCollection,
    required this.autoMopWash,
    required this.autoMopDry,
    required this.voiceVolume,
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
      isMopAttached: false,
      faultCodes: const [],
      faultMessages: const [],
      cleaningType: CleaningType.vacuumAndMop,
      cleaningPasses: 1,
      carpetPreference: CarpetPreference.adaptive,
      autoDustCollection: false,
      autoMopWash: false,
      autoMopDry: false,
      voiceVolume: 100,
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

  /// Whether the mop pad is currently fitted, from the robot's `mop_state`
  /// data point. False when the robot doesn't report one at all.
  final bool isMopAttached;

  /// Tuya's own reachability flag for the physical robot. Defaults to
  /// true so transports that don't report it (simulator/BLE/WiFi) behave
  /// exactly as before rather than showing everything as offline.
  final bool deviceOnline;

  /// Active fault numbers exactly as the robot reported them via its
  /// `total_error` bitmap. The number-to-meaning mapping lives in the
  /// vendor's panel translations rather than any API, so these stay as
  /// numbers unless confirmed against the real device.
  final List<int> faultCodes;

  /// Human-readable text for each active fault, in the same order as
  /// [faultCodes]. Populated by the transport that decoded them, since
  /// only it knows which codes have been confirmed on real hardware.
  final List<String> faultMessages;

  final CleaningType cleaningType;
  final int cleaningPasses;
  final CarpetPreference carpetPreference;
  final bool autoDustCollection;
  final bool autoMopWash;
  final bool autoMopDry;

  /// 0-100, from the real `volume_set` DP.
  final int voiceVolume;

  final DateTime lastUpdated;

  bool get isOnline => connection == RobotConnectionState.connected;
  bool get hasErrors => activeErrors.isNotEmpty;
  bool get isCleaning => activity == ActivityState.cleaning;

  /// Named lookups into [faultCodes] for the specific physical components
  /// the dashboard/dock illustration highlights individually. Codes are
  /// empirically confirmed against the real Milagrow W300 (see
  /// TuyaFault._confirmedFaults) — kept here, not re-derived per call site,
  /// so every screen that cares about one specific component agrees.
  bool get isDustBagMissing => faultCodes.contains(18);
  bool get isMopPadsRemoved => faultCodes.contains(21);
  bool get isCleanWaterTankMissing => faultCodes.contains(24);
  bool get isSewageTankMissing => faultCodes.contains(25);
  bool get isDustBinMissing => faultCodes.contains(46);

  /// Whether the ROBOT ITSELF is reachable, as opposed to [isOnline]
  /// which only says this app can reach the backend. Tuya's device
  /// shadow keeps serving its last-known values with success:true long
  /// after a robot goes dark, so without this a powered-off robot looks
  /// perfectly connected — surfaced from Tuya's own reachability flag.
  bool get isRobotReachable => deviceOnline;

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
    bool? isMopAttached,
    bool? deviceOnline,
    List<int>? faultCodes,
    List<String>? faultMessages,
    CleaningType? cleaningType,
    int? cleaningPasses,
    CarpetPreference? carpetPreference,
    bool? autoDustCollection,
    bool? autoMopWash,
    bool? autoMopDry,
    int? voiceVolume,
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
      isMopAttached: isMopAttached ?? this.isMopAttached,
      deviceOnline: deviceOnline ?? this.deviceOnline,
      faultCodes: faultCodes ?? this.faultCodes,
      faultMessages: faultMessages ?? this.faultMessages,
      cleaningType: cleaningType ?? this.cleaningType,
      cleaningPasses: cleaningPasses ?? this.cleaningPasses,
      carpetPreference: carpetPreference ?? this.carpetPreference,
      autoDustCollection: autoDustCollection ?? this.autoDustCollection,
      autoMopWash: autoMopWash ?? this.autoMopWash,
      autoMopDry: autoMopDry ?? this.autoMopDry,
      voiceVolume: voiceVolume ?? this.voiceVolume,
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
        isMopAttached,
        deviceOnline,
        faultCodes,
        faultMessages,
        cleaningType,
        cleaningPasses,
        carpetPreference,
        autoDustCollection,
        autoMopWash,
        autoMopDry,
        voiceVolume,
        lastUpdated,
      ];
}

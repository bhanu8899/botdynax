/// Transport-level connection state, independent of which transport
/// implementation (BLE/WiFi/MQTT/Simulator) is active.
enum RobotConnectionState { disconnected, connecting, connected, reconnecting }

/// What the robot is doing right now.
enum ActivityState {
  idle,
  cleaning,
  paused,
  returningToDock,
  docked,
  charging,
  error,
}

/// Vacuum suction power presets. [custom] is used alongside a manual
/// slider value carried separately on the status/command payload.
enum VacuumPower { silent, eco, standard, strong, turbo, maximum, custom }

/// Mop water flow presets.
enum WaterFlow { off, low, medium, high, ultra }

/// Mopping path pattern.
enum MopPattern { yPattern, sPattern, crossPattern }

/// The cleaning strategy requested for the current run.
enum CleaningMode { auto, room, zone, spot, custom }

/// Consumable/accessory kind tracked for replacement reminders.
enum ConsumableType { mainBrush, sideBrush, filter, mopPad, battery, sensor }

/// Robot fault codes surfaced to the user with a human-readable message.
enum RobotErrorCode {
  none,
  stuck,
  wheelLifted,
  dustBinMissing,
  dustBinFull,
  waterTankEmpty,
  waterTankMissing,
  sideBrushTangled,
  mainBrushTangled,
  sensorDirty,
  lowBattery,
  cliffSensorBlocked,
  unableToReturnToDock,
  firmwareUpdateFailed,
  unknown,
}

extension RobotErrorCodeMessage on RobotErrorCode {
  String get message => switch (this) {
        RobotErrorCode.none => 'No errors',
        RobotErrorCode.stuck => 'Robot is stuck and needs help',
        RobotErrorCode.wheelLifted => 'Wheel is lifted off the ground',
        RobotErrorCode.dustBinMissing => 'Dust bin is not installed',
        RobotErrorCode.dustBinFull => 'Dust bin is full',
        RobotErrorCode.waterTankEmpty => 'Water tank is empty',
        RobotErrorCode.waterTankMissing => 'Water tank is not installed',
        RobotErrorCode.sideBrushTangled => 'Side brush is tangled',
        RobotErrorCode.mainBrushTangled => 'Main brush is tangled',
        RobotErrorCode.sensorDirty => 'A sensor needs cleaning',
        RobotErrorCode.lowBattery => 'Battery is critically low',
        RobotErrorCode.cliffSensorBlocked => 'Cliff sensor is blocked',
        RobotErrorCode.unableToReturnToDock => 'Unable to find the way back to dock',
        RobotErrorCode.firmwareUpdateFailed => 'Firmware update failed',
        RobotErrorCode.unknown => 'An unknown error occurred',
      };
}

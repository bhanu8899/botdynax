import 'package:equatable/equatable.dart';

import 'robot_enums.dart';

/// Every action the app can issue to a robot. Sealed so transports and the
/// controller get exhaustive-switch safety when encoding/handling commands.
sealed class RobotCommand extends Equatable {
  const RobotCommand();

  @override
  List<Object?> get props => [];
}

class StartCleaningCommand extends RobotCommand {
  const StartCleaningCommand({this.mode = CleaningMode.auto});
  final CleaningMode mode;
  @override
  List<Object?> get props => [mode];
}

class PauseCleaningCommand extends RobotCommand {
  const PauseCleaningCommand();
}

class ResumeCleaningCommand extends RobotCommand {
  const ResumeCleaningCommand();
}

class StopCleaningCommand extends RobotCommand {
  const StopCleaningCommand();
}

class ReturnToDockCommand extends RobotCommand {
  const ReturnToDockCommand();
}

class SpotCleanCommand extends RobotCommand {
  const SpotCleanCommand();
}

class RoomCleanCommand extends RobotCommand {
  const RoomCleanCommand(this.roomIds);
  final List<String> roomIds;
  @override
  List<Object?> get props => [roomIds];
}

class ZoneCleanCommand extends RobotCommand {
  const ZoneCleanCommand(this.zoneIds);
  final List<String> zoneIds;
  @override
  List<Object?> get props => [zoneIds];
}

class CustomCleanCommand extends RobotCommand {
  const CustomCleanCommand({required this.roomIds, required this.power, required this.waterFlow});
  final List<String> roomIds;
  final VacuumPower power;
  final WaterFlow waterFlow;
  @override
  List<Object?> get props => [roomIds, power, waterFlow];
}

class SetVacuumPowerCommand extends RobotCommand {
  const SetVacuumPowerCommand(this.power, {this.customLevel});
  final VacuumPower power;

  /// 0.0 - 1.0, used only when [power] is [VacuumPower.custom].
  final double? customLevel;
  @override
  List<Object?> get props => [power, customLevel];
}

class SetWaterLevelCommand extends RobotCommand {
  const SetWaterLevelCommand(this.level, {this.pattern});
  final WaterFlow level;
  final MopPattern? pattern;
  @override
  List<Object?> get props => [level, pattern];
}

class FindRobotCommand extends RobotCommand {
  const FindRobotCommand();
}

class EmergencyStopCommand extends RobotCommand {
  const EmergencyStopCommand();
}

class SetChildLockCommand extends RobotCommand {
  const SetChildLockCommand(this.enabled);
  final bool enabled;
  @override
  List<Object?> get props => [enabled];
}

class StartOtaCommand extends RobotCommand {
  const StartOtaCommand(this.firmwareVersion);
  final String firmwareVersion;
  @override
  List<Object?> get props => [firmwareVersion];
}

class RestartRobotCommand extends RobotCommand {
  const RestartRobotCommand();
}

class FactoryResetCommand extends RobotCommand {
  const FactoryResetCommand();
}

class GetBatteryCommand extends RobotCommand {
  const GetBatteryCommand();
}

class GetMapCommand extends RobotCommand {
  const GetMapCommand();
}

class GetStatusCommand extends RobotCommand {
  const GetStatusCommand();
}

class GetErrorsCommand extends RobotCommand {
  const GetErrorsCommand();
}

class GetLogsCommand extends RobotCommand {
  const GetLogsCommand();
}

/// Renames a room on the currently active map.
class RenameRoomCommand extends RobotCommand {
  const RenameRoomCommand({required this.roomId, required this.name});
  final String roomId;
  final String name;
  @override
  List<Object?> get props => [roomId, name];
}

/// Manual drive command for the remote-control joystick.
class DriveCommand extends RobotCommand {
  const DriveCommand({required this.linear, required this.angular});

  /// -1.0 (full reverse) .. 1.0 (full forward)
  final double linear;

  /// -1.0 (full left) .. 1.0 (full right)
  final double angular;

  @override
  List<Object?> get props => [linear, angular];
}

/// Direct vacuum motor on/off — used during manual remote-control driving,
/// distinct from [SetVacuumPowerCommand]'s power-level presets used during
/// autonomous cleaning.
class SetVacuumMotorCommand extends RobotCommand {
  const SetVacuumMotorCommand(this.enabled);
  final bool enabled;
  @override
  List<Object?> get props => [enabled];
}

/// Direct water/mop pump on/off — used during manual remote-control driving.
class SetWaterPumpCommand extends RobotCommand {
  const SetWaterPumpCommand(this.enabled);
  final bool enabled;
  @override
  List<Object?> get props => [enabled];
}

/// Toggles the robot's headlight/indicator LED.
class SetLedCommand extends RobotCommand {
  const SetLedCommand(this.enabled);
  final bool enabled;
  @override
  List<Object?> get props => [enabled];
}

/// Vacuum-only / mop-only / both / mop-after-vacuum.
class SetCleaningTypeCommand extends RobotCommand {
  const SetCleaningTypeCommand(this.type);
  final CleaningType type;
  @override
  List<Object?> get props => [type];
}

/// How many passes the robot makes per room (1 or 2).
class SetCleaningPassesCommand extends RobotCommand {
  const SetCleaningPassesCommand(this.passes);
  final int passes;
  @override
  List<Object?> get props => [passes];
}

/// How the robot treats carpet during a clean.
class SetCarpetPreferenceCommand extends RobotCommand {
  const SetCarpetPreferenceCommand(this.preference);
  final CarpetPreference preference;
  @override
  List<Object?> get props => [preference];
}

/// Sends the robot to the dock and triggers a dust-collection cycle now.
class TriggerDustCollectionCommand extends RobotCommand {
  const TriggerDustCollectionCommand();
}

/// Triggers the dock's mop-washing cycle now.
class TriggerMopWashCommand extends RobotCommand {
  const TriggerMopWashCommand();
}

/// Triggers the dock's mop-drying (warm air) cycle now.
class TriggerMopDryCommand extends RobotCommand {
  const TriggerMopDryCommand();
}

/// Sets whether the dock collects dust automatically after each clean.
class SetAutoDustCollectionCommand extends RobotCommand {
  const SetAutoDustCollectionCommand(this.enabled);
  final bool enabled;
  @override
  List<Object?> get props => [enabled];
}

/// Sets whether the dock washes the mop automatically.
class SetAutoMopWashCommand extends RobotCommand {
  const SetAutoMopWashCommand(this.enabled);
  final bool enabled;
  @override
  List<Object?> get props => [enabled];
}

/// Sets whether the dock dries the mop automatically after washing.
class SetAutoMopDryCommand extends RobotCommand {
  const SetAutoMopDryCommand(this.enabled);
  final bool enabled;
  @override
  List<Object?> get props => [enabled];
}

/// Resets a consumable's tracked life back to 100%, for after a physical
/// replacement.
class ResetConsumableLifeCommand extends RobotCommand {
  const ResetConsumableLifeCommand(this.type);
  final ConsumableType type;
  @override
  List<Object?> get props => [type];
}

/// Sets the robot's voice-prompt volume, 0-100.
class SetVolumeCommand extends RobotCommand {
  const SetVolumeCommand(this.percent);
  final int percent;
  @override
  List<Object?> get props => [percent];
}

/// Requests the standard "clean the whole home" run using room-selection
/// mode rather than the default smart-clean mode. This device's `mode` DP
/// does support a `select_room` value, but exposes no DP to specify which
/// rooms — so this triggers the mode, not a per-room selection.
class SelectRoomCleanCommand extends RobotCommand {
  const SelectRoomCleanCommand();
}

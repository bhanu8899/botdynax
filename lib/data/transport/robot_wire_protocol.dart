import '../../domain/entities/consumable.dart';
import '../../domain/entities/map_data.dart';
import '../../domain/entities/robot_command.dart';
import '../../domain/entities/robot_enums.dart';
import '../../domain/entities/robot_status.dart';
import '../../domain/transport/robot_transport.dart';

/// JSON wire format shared by [BLETransport], [WifiTransport], and
/// [MQTTTransport]. This is a reference schema, not a firmware contract —
/// swap the field names/encoding here to match your actual BotDyNax
/// firmware protocol; every transport funnels through this one codec so
/// there is exactly one place to update.
abstract final class RobotWireProtocol {
  static Map<String, dynamic> encodeCommand(RobotCommand command) {
    return switch (command) {
      StartCleaningCommand(:final mode) => {'cmd': 'start', 'mode': mode.name},
      PauseCleaningCommand() => {'cmd': 'pause'},
      ResumeCleaningCommand() => {'cmd': 'resume'},
      StopCleaningCommand() => {'cmd': 'stop'},
      ReturnToDockCommand() => {'cmd': 'return_home'},
      SpotCleanCommand() => {'cmd': 'spot_clean'},
      RoomCleanCommand(:final roomIds) => {'cmd': 'room_clean', 'rooms': roomIds},
      ZoneCleanCommand(:final zoneIds) => {'cmd': 'zone_clean', 'zones': zoneIds},
      CustomCleanCommand(:final roomIds, :final power, :final waterFlow) => {
          'cmd': 'custom_clean',
          'rooms': roomIds,
          'power': power.name,
          'water': waterFlow.name,
        },
      SetVacuumPowerCommand(:final power, :final customLevel) => {
          'cmd': 'set_power',
          'power': power.name,
          if (customLevel != null) 'level': customLevel,
        },
      SetWaterLevelCommand(:final level, :final pattern) => {
          'cmd': 'set_water',
          'level': level.name,
          if (pattern != null) 'pattern': pattern.name,
        },
      FindRobotCommand() => {'cmd': 'find_me'},
      EmergencyStopCommand() => {'cmd': 'emergency_stop'},
      SetChildLockCommand(:final enabled) => {'cmd': 'child_lock', 'enabled': enabled},
      RenameRoomCommand(:final roomId, :final name) => {'cmd': 'rename_room', 'room_id': roomId, 'name': name},
      StartOtaCommand(:final firmwareVersion) => {'cmd': 'ota_start', 'version': firmwareVersion},
      RestartRobotCommand() => {'cmd': 'restart'},
      FactoryResetCommand() => {'cmd': 'factory_reset'},
      GetBatteryCommand() => {'cmd': 'get_battery'},
      GetMapCommand() => {'cmd': 'get_map'},
      GetStatusCommand() => {'cmd': 'get_status'},
      GetErrorsCommand() => {'cmd': 'get_errors'},
      GetLogsCommand() => {'cmd': 'get_logs'},
      DriveCommand(:final linear, :final angular) => {'cmd': 'drive', 'linear': linear, 'angular': angular},
      SetVacuumMotorCommand(:final enabled) => {'cmd': 'vacuum_motor', 'enabled': enabled},
      SetWaterPumpCommand(:final enabled) => {'cmd': 'water_pump', 'enabled': enabled},
      SetLedCommand(:final enabled) => {'cmd': 'led', 'enabled': enabled},
    };
  }

  static RobotStatus decodeStatus(Map<String, dynamic> json, RobotStatus previous) {
    return previous.copyWith(
      connection: RobotConnectionState.connected,
      activity: ActivityState.values.byName((json['activity'] as String?) ?? previous.activity.name),
      batteryPercent: (json['battery'] as num?)?.toDouble() ?? previous.batteryPercent,
      isCharging: json['charging'] as bool? ?? previous.isCharging,
      vacuumPower: json['power'] != null
          ? VacuumPower.values.byName(json['power'] as String)
          : previous.vacuumPower,
      waterFlow:
          json['water'] != null ? WaterFlow.values.byName(json['water'] as String) : previous.waterFlow,
      currentRoom: json['room'] as String?,
      currentTask: json['task'] as String?,
      areaCleanedSqm: (json['area_sqm'] as num?)?.toDouble() ?? previous.areaCleanedSqm,
      cleaningElapsed: json['elapsed_s'] != null
          ? Duration(seconds: json['elapsed_s'] as int)
          : previous.cleaningElapsed,
      cleaningRemaining: json['remaining_s'] != null
          ? Duration(seconds: json['remaining_s'] as int)
          : previous.cleaningRemaining,
      firmwareVersion: json['firmware'] as String? ?? previous.firmwareVersion,
      waterTankPercent: (json['water_tank'] as num?)?.toDouble() ?? previous.waterTankPercent,
      dustBinPercent: (json['dust_bin'] as num?)?.toDouble() ?? previous.dustBinPercent,
      isChildLockOn: json['child_lock'] as bool? ?? previous.isChildLockOn,
      consumables: json['consumables'] != null
          ? (json['consumables'] as List<dynamic>)
              .map((dynamic e) => _decodeConsumable(e as Map<String, dynamic>))
              .toList()
          : previous.consumables,
      activeErrors: json['errors'] != null
          ? (json['errors'] as List<dynamic>)
              .map((dynamic e) => RobotErrorCode.values.byName(e as String))
              .toList()
          : previous.activeErrors,
      lastUpdated: DateTime.now(),
    );
  }

  static Consumable _decodeConsumable(Map<String, dynamic> json) {
    return Consumable(
      type: ConsumableType.values.byName(json['type'] as String),
      remainingPercent: (json['remaining'] as num).toDouble(),
      ratedLifetimeMinutes: json['rated_minutes'] as int,
      usedMinutes: json['used_minutes'] as int,
    );
  }

  static CleaningMap decodeMap(Map<String, dynamic> json, CleaningMap previous) {
    return previous.copyWith(
      robotPose: json['robot_pose'] != null ? _decodePose(json['robot_pose'] as Map<String, dynamic>) : previous.robotPose,
      dockPose: json['dock_pose'] != null ? _decodePose(json['dock_pose'] as Map<String, dynamic>) : previous.dockPose,
      path: json['path'] != null
          ? (json['path'] as List<dynamic>).map((dynamic e) => _decodePoint(e as Map<String, dynamic>)).toList()
          : previous.path,
      updatedAt: DateTime.now(),
    );
  }

  static Pose _decodePose(Map<String, dynamic> json) {
    return Pose(
      position: _decodePoint(json['position'] as Map<String, dynamic>),
      headingRadians: (json['heading'] as num).toDouble(),
    );
  }

  static MapPoint _decodePoint(Map<String, dynamic> json) {
    return MapPoint((json['x'] as num).toDouble(), (json['y'] as num).toDouble());
  }

  static RobotEvent decodeEvent(Map<String, dynamic> json) {
    final String type = json['event'] as String;
    return switch (type) {
      'cleaning_started' => const CleaningStartedEvent(),
      'cleaning_completed' => CleaningCompletedEvent(
          areaCleanedSqm: (json['area_sqm'] as num).toDouble(),
          duration: Duration(seconds: json['duration_s'] as int),
        ),
      'error' => RobotErrorEvent(RobotErrorCode.values.byName(json['code'] as String)),
      'firmware_available' => FirmwareUpdateAvailableEvent(json['version'] as String),
      _ => const RobotErrorEvent(RobotErrorCode.unknown),
    };
  }
}

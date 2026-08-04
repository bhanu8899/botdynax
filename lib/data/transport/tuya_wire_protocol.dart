import '../../domain/entities/consumable.dart';
import '../../domain/entities/robot_command.dart';
import '../../domain/entities/robot_enums.dart';
import '../../domain/entities/robot_status.dart';

/// Maps between our domain model and the REAL Tuya DP (data point) schema
/// confirmed live against the user's Milagrow iMap Max W300
/// (device_id `d784c044cd0ee1361f329a`, product_id `LW41MF`) via
/// `GET /tuya/robots/:robotId/functions` and `/status`. Unlike a generic
/// "standard sweeper category" template, every code/enum value below was
/// read back from that device, not guessed.
///
/// This product has no mop/water system and no child-lock DP — those
/// domain commands are intentionally no-ops here (see [TuyaWireProtocol]).
abstract final class TuyaDpCodes {
  static const String powerGo = 'power_go'; // bool: true = start/resume cleaning, false = stop
  static const String pause = 'pause'; // bool: true = paused in place
  static const String switchCharge = 'switch_charge'; // bool: true = return to dock
  static const String mode = 'mode'; // enum: smart | zone | pose
  static const String customizeModeSwitch = 'customize_mode_switch'; // bool
  static const String suction = 'suction'; // enum: gentle | normal | strong (only 3 levels)
  static const String breakClean = 'break_clean'; // bool
  static const String cleanTime = 'clean_time'; // integer, read-only, minutes this session
  static const String cleanArea = 'clean_area'; // integer, read-only, sq meters this session
  static const String edgeBrush = 'edge_brush'; // integer, side brush remaining life
  static const String rollBrush = 'roll_brush'; // integer, main brush remaining life
  static const String filter = 'filter'; // integer, filter remaining life
  static const String electricityLeft = 'electricity_left'; // integer 0-100, battery (NOT battery_percentage)
  static const String volumeSet = 'volume_set'; // integer 0-100
  static const String direction = 'direction_control'; // enum: forward | turn_left | turn_right | stop (NO backward)
  static const String seek = 'seek'; // bool, find-my-robot chime
  static const String status = 'status'; // read-only string enum, full range not confirmed
}

class TuyaCommand {
  const TuyaCommand(this.code, this.value);
  final String code;
  final Object value;
}

abstract final class TuyaWireProtocol {
  /// Returns ORDERED batches, each sent as its own `POST /commands` call,
  /// awaited sequentially rather than merged into one request. Some Tuya
  /// vacuum firmwares are order-sensitive about `mode`/`suction` vs. the
  /// `power_go` start toggle — committing the mode/power-level DP first,
  /// then toggling `power_go` in a second call, matches how Tuya's own
  /// reference app sequences these for sweeper-category devices, rather
  /// than relying on both landing in a single batch.
  static List<List<TuyaCommand>> encodeCommand(RobotCommand command) {
    return switch (command) {
      StartCleaningCommand(:final mode) => [
          [TuyaCommand(TuyaDpCodes.mode, _encodeCleaningMode(mode))],
          [const TuyaCommand(TuyaDpCodes.powerGo, true)],
        ],
      ResumeCleaningCommand() => [
          [const TuyaCommand(TuyaDpCodes.pause, false)],
        ],
      PauseCleaningCommand() => [
          [const TuyaCommand(TuyaDpCodes.pause, true)],
        ],
      StopCleaningCommand() => [
          [const TuyaCommand(TuyaDpCodes.powerGo, false)],
        ],
      ReturnToDockCommand() => [
          [const TuyaCommand(TuyaDpCodes.switchCharge, true)],
        ],
      SpotCleanCommand() => [
          [const TuyaCommand(TuyaDpCodes.mode, 'pose')],
          [const TuyaCommand(TuyaDpCodes.powerGo, true)],
        ],
      // This device's `mode` enum (smart/zone/pose) has no per-room
      // selection — room picking is app/map-side only, so this falls back
      // to a full smart clean.
      RoomCleanCommand() => [
          [const TuyaCommand(TuyaDpCodes.mode, 'smart')],
          [const TuyaCommand(TuyaDpCodes.powerGo, true)],
        ],
      ZoneCleanCommand() => [
          [const TuyaCommand(TuyaDpCodes.mode, 'zone')],
          [const TuyaCommand(TuyaDpCodes.powerGo, true)],
        ],
      // No water/mop DP on this device — waterFlow is dropped.
      CustomCleanCommand(:final power) => [
          [TuyaCommand(TuyaDpCodes.suction, _encodeSuction(power))],
          [const TuyaCommand(TuyaDpCodes.powerGo, true)],
        ],
      SetVacuumPowerCommand(:final power) => [
          [TuyaCommand(TuyaDpCodes.suction, _encodeSuction(power))],
        ],
      FindRobotCommand() => [
          [const TuyaCommand(TuyaDpCodes.seek, true)],
        ],
      EmergencyStopCommand() => [
          [const TuyaCommand(TuyaDpCodes.pause, true)],
        ],
      DriveCommand(:final linear, :final angular) => [
          [TuyaCommand(TuyaDpCodes.direction, _encodeDirection(linear, angular))],
        ],
      // No mop/water DP, no child-lock DP, and manual motor/pump/LED/room-
      // naming controls aren't part of this device's schema at all.
      SetWaterLevelCommand() ||
      SetChildLockCommand() ||
      StartOtaCommand() ||
      RestartRobotCommand() ||
      FactoryResetCommand() ||
      GetBatteryCommand() ||
      GetMapCommand() ||
      GetStatusCommand() ||
      GetErrorsCommand() ||
      GetLogsCommand() ||
      RenameRoomCommand() ||
      SetVacuumMotorCommand() ||
      SetWaterPumpCommand() ||
      SetLedCommand() =>
        const [],
    };
  }

  static RobotStatus decodeStatus(List<Map<String, dynamic>> points, RobotStatus previous) {
    RobotStatus status = previous;
    bool? powerGo;
    bool? pause;
    bool? switchCharge;
    String? statusStr;

    for (final Map<String, dynamic> point in points) {
      final String code = point['code'] as String;
      final Object? value = point['value'];

      switch (code) {
        case TuyaDpCodes.electricityLeft:
          status = status.copyWith(batteryPercent: (value! as num) / 100.0);
        case TuyaDpCodes.cleanArea:
          status = status.copyWith(areaCleanedSqm: (value! as num).toDouble());
        case TuyaDpCodes.cleanTime:
          status = status.copyWith(cleaningElapsed: Duration(minutes: value! as int));
        case TuyaDpCodes.suction:
          status = status.copyWith(vacuumPower: _decodeSuction(value! as String));
        case TuyaDpCodes.rollBrush:
          status = status.copyWith(
            consumables: _updateConsumable(status.consumables, ConsumableType.mainBrush, value! as num),
          );
        case TuyaDpCodes.edgeBrush:
          status = status.copyWith(
            consumables: _updateConsumable(status.consumables, ConsumableType.sideBrush, value! as num),
          );
        case TuyaDpCodes.filter:
          status = status.copyWith(
            consumables: _updateConsumable(status.consumables, ConsumableType.filter, value! as num),
          );
        case TuyaDpCodes.powerGo:
          powerGo = value! as bool;
        case TuyaDpCodes.pause:
          pause = value! as bool;
        case TuyaDpCodes.switchCharge:
          switchCharge = value! as bool;
        case TuyaDpCodes.status:
          statusStr = value as String?;
      }
    }

    final ActivityState? resolvedActivity = _resolveActivity(
      powerGo: powerGo,
      pause: pause,
      switchCharge: switchCharge,
      statusStr: statusStr,
      previous: status.activity,
    );
    if (resolvedActivity != null) {
      status = status.copyWith(
        activity: resolvedActivity,
        isCharging: resolvedActivity == ActivityState.charging || resolvedActivity == ActivityState.docked,
        // This device reports faults only as a bare `status: "fault"` with
        // no accompanying fault code, so the specific cause genuinely
        // isn't knowable from the API — surface it as `unknown` rather
        // than inventing a more specific-sounding reason.
        activeErrors: resolvedActivity == ActivityState.error ? const [RobotErrorCode.unknown] : const [],
      );
    }

    return status.copyWith(connection: RobotConnectionState.connected, lastUpdated: DateTime.now());
  }

  /// `edge_brush`/`roll_brush`/`filter` are read here as 0-100 remaining
  /// life percentages, per Tuya's documented convention for these codes in
  /// the robot-vacuum standard instruction set. Rated lifetimes below are
  /// typical manufacturer defaults, not confirmed for the W300 specifically
  /// — cross-check against the Milagrow app if the numbers look off.
  static List<Consumable> _updateConsumable(List<Consumable> consumables, ConsumableType type, num rawValue) {
    final double remainingPercent = (rawValue.toDouble() / 100.0).clamp(0.0, 1.0);
    final int ratedLifetimeMinutes = switch (type) {
      ConsumableType.mainBrush => 400 * 60,
      ConsumableType.sideBrush => 200 * 60,
      ConsumableType.filter => 100 * 60,
      _ => 0,
    };
    final Consumable updated = Consumable(
      type: type,
      remainingPercent: remainingPercent,
      ratedLifetimeMinutes: ratedLifetimeMinutes,
      usedMinutes: (ratedLifetimeMinutes * (1 - remainingPercent)).round(),
    );
    final int index = consumables.indexWhere((c) => c.type == type);
    if (index == -1) return [...consumables, updated];
    final List<Consumable> copy = [...consumables];
    copy[index] = updated;
    return copy;
  }

  static ActivityState? _resolveActivity({
    required bool? powerGo,
    required bool? pause,
    required bool? switchCharge,
    required String? statusStr,
    required ActivityState previous,
  }) {
    if (pause == true) return ActivityState.paused;
    if (statusStr != null) {
      final ActivityState? mapped = _decodeStatusString(statusStr);
      if (mapped != null) return mapped;
    }
    if (switchCharge == true) return ActivityState.returningToDock;
    if (powerGo != null) return powerGo ? ActivityState.cleaning : ActivityState.idle;
    if (pause == false) return previous == ActivityState.paused ? ActivityState.cleaning : previous;
    return null;
  }

  /// Maps the read-only `status` DP to an activity state.
  ///
  /// Two sources, both real: the values Tuya *declares* for this product
  /// via `GET /v1.1/devices/{id}/specifications`, and the values the robot
  /// has actually *reported* in its device event logs. Those sets differ —
  /// this firmware emits `relocation`, `washing`, `airing`,
  /// `relocation_recharge`, `collecting_dust`, `smart` and `fault`, none of
  /// which appear in its declared enum. Both are handled here; anything
  /// still unrecognized falls back to whatever
  /// `power_go`/`pause`/`switch_charge` resolved rather than guessing.
  static ActivityState? _decodeStatusString(String value) => switch (value) {
        // Actively cleaning. `smart`/`zone`/`pose` mirror the active mode;
        // `relocation` is the robot re-localising mid-run, still underway.
        'smart' ||
        'zone' ||
        'pose' ||
        'cleaning' ||
        'zone_clean' ||
        'part_clean' ||
        'goto_pos' ||
        'relocation' =>
          ActivityState.cleaning,

        'paused' || 'pos_unarrive' => ActivityState.paused,

        'goto_charge' || 'relocation_recharge' => ActivityState.returningToDock,

        'charging' => ActivityState.charging,

        // Dock-side maintenance routines: the robot is seated on the dock
        // throughout, so these read as docked rather than as a distinct
        // activity the rest of the app has no concept of.
        'charge_done' ||
        'chargedone' ||
        'sleep' ||
        'washing' ||
        'airing' ||
        'collecting_dust' ||
        'pos_arrived' =>
          ActivityState.docked,

        'standby' => ActivityState.idle,

        // The only fault signal this device exposes — a bare `fault`, with
        // no accompanying code identifying which fault it is (no fault DP
        // exists in either the declared spec or 7 days of event logs).
        'fault' => ActivityState.error,

        _ => null,
      };

  static String _encodeCleaningMode(CleaningMode mode) => switch (mode) {
        CleaningMode.auto => 'smart',
        CleaningMode.room => 'smart',
        CleaningMode.zone => 'zone',
        CleaningMode.spot => 'pose',
        CleaningMode.custom => 'smart',
      };

  static String _encodeSuction(VacuumPower power) => switch (power) {
        VacuumPower.silent => 'gentle',
        VacuumPower.eco => 'gentle',
        VacuumPower.standard => 'normal',
        VacuumPower.strong => 'strong',
        VacuumPower.turbo => 'strong',
        VacuumPower.maximum => 'strong',
        VacuumPower.custom => 'normal',
      };

  static VacuumPower _decodeSuction(String value) => switch (value) {
        'gentle' => VacuumPower.eco,
        'normal' => VacuumPower.standard,
        'strong' => VacuumPower.strong,
        _ => VacuumPower.standard,
      };

  /// `direction_control` has no reverse option on this device — a negative
  /// [linear] with no meaningful [angular] collapses to `stop` rather than
  /// driving backward, since there is nothing to send for it.
  static String _encodeDirection(double linear, double angular) {
    const double deadZone = 0.15;
    if (angular.abs() > linear.abs() && angular.abs() > deadZone) {
      return angular > 0 ? 'turn_right' : 'turn_left';
    }
    if (linear > deadZone) return 'forward';
    return 'stop';
  }
}

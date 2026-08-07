import 'dart:convert';

import '../../domain/entities/consumable.dart';
import '../../domain/entities/robot_command.dart';
import '../../domain/entities/robot_enums.dart';
import '../../domain/entities/robot_status.dart';

/// Maps between our domain model and the REAL Tuya DP (data point) schema
/// of the user's Milagrow iMap Max W300 (device_id `d7ae521a982d49fbc4ikal`
/// as of its 2026-08-06 re-pairing, product_id `LW41MF`). Every code and
/// enum value below was read back from that device, not guessed.
///
/// Important: two different schemas exist for this robot. Tuya's v1.x
/// `/specifications` endpoint returns only the *standard instruction set*
/// (17 DPs, some renamed), while the v2.0 thing model
/// (`/v2.0/cloud/thing/{id}/model`) returns the device's real definition —
/// 37 DPs, including `total_error`, `mop_state`, `water_output`,
/// `sweep_mop_mode` and `mop_life`, which v1.x omits entirely. Status is
/// read from the v2.0 shadow; commands still go through the v1.x
/// `/commands` endpoint, so v1 code names are used when sending.
abstract final class TuyaDpCodes {
  // Codes as they appear in the device's real v2.0 thing model. Tuya's
  // v1.x "standard instruction set" renames several of these, so the v1
  // aliases are listed alongside and both are accepted when decoding —
  // that way status keeps parsing regardless of which endpoint served it.
  static const String switchGo = 'switch_go'; // bool: start/stop cleaning
  static const String powerGoV1 = 'power_go'; // v1 alias of switch_go
  static const String pause = 'pause'; // bool: true = paused in place
  static const String switchCharge = 'switch_charge'; // bool: true = return to dock
  static const String mode = 'mode'; // enum: smart|goto_charge|zone|pose|select_room|manual|quick_mapping
  static const String customizeModeSwitch = 'customize_mode_switch'; // bool
  static const String suction = 'suction'; // enum: closed | gentle | normal | strong | max
  static const String breakClean = 'break_clean'; // bool
  static const String cleanTime = 'clean_time'; // integer, read-only, minutes this session
  static const String cleanArea = 'clean_area'; // integer, read-only, sq meters this session
  static const String volumeSet = 'volume_set'; // integer 0-100
  static const String direction = 'direction_control'; // enum: forward|turn_left|turn_right|stop (no reverse)
  static const String seek = 'seek'; // bool, find-my-robot chime
  static const String status = 'status'; // read-only enum, 28 values in the real model

  // Consumable life. v1 exposes these without the `_life` suffix.
  static const String edgeBrushLife = 'edge_brush_life';
  static const String edgeBrushV1 = 'edge_brush';
  static const String rollBrushLife = 'roll_brush_life';
  static const String rollBrushV1 = 'roll_brush';
  static const String filterLife = 'filter_life';
  static const String filterV1 = 'filter';
  static const String mopLife = 'mop_life'; // only present in the v2 model

  static const String batteryPercentage = 'battery_percentage';
  static const String electricityLeftV1 = 'electricity_left'; // v1 alias

  // Only exposed by the v2.0 thing model — absent from v1.x entirely.
  static const String mopState = 'mop_state'; // enum: none | installed
  static const String waterOutput = 'water_output'; // enum: closed | low | middle | high
  static const String sweepMopMode = 'sweep_mop_mode'; // enum: only_sweep|only_mop|both_work|clean_before_mop
  static const String cleanTimes = 'clean_times'; // integer 1-2, passes per room
  static const String carpetCleanPrefer = 'carpet_clean_prefer'; // enum: adaptive | evade | ignore

  // Dock/station routines — all confirmed in the v2.0 model.
  static const String manualDustCollection = 'manual_dust_collection'; // bool, trigger now
  static const String autoDustCollection = 'auto_dust_collection'; // bool, toggle
  static const String wash = 'wash'; // bool, trigger mop-wash now
  static const String manualAir = 'manual_air'; // bool, trigger drying now
  static const String autoAir = 'auto_air'; // bool, toggle

  /// Raw fault bitmap. Per the device model: hex, one byte per active
  /// fault (e.g. `0102041E` = faults 1, 2, 4 and 30 at once); `00` means
  /// no fault / fault cleared. Delivered base64-encoded over the API.
  static const String totalError = 'total_error';
}

/// One active fault reported via [TuyaDpCodes.totalError].
///
/// The device transmits fault *numbers* only — the number-to-meaning
/// mapping lives in Tuya's per-product panel translations, not in the
/// thing model, so it cannot be derived from any API. [_confirmedFaults]
/// therefore contains ONLY codes observed on the real Milagrow W300 by
/// physically triggering the condition and reading back `total_error`.
/// Anything else is reported by number rather than mislabelled.
class TuyaFault {
  const TuyaFault(this.code);

  final int code;

  /// Empirically confirmed against the real device. Extend this only by
  /// actually reproducing a fault and reading the resulting code — never
  /// by guessing from another vendor's fault table.
  /// Every entry below was captured by physically triggering the condition
  /// on the real robot and reading back `total_error` — each one toggled
  /// out/in repeatedly from a confirmed-clear (`0x00`) baseline, so the
  /// correlation is reproducible rather than a one-off coincidence.
  static const Map<int, String> _confirmedFaults = <int, String>{
    // Dust bag pulled from the dock: 0x12 while out, 0x00 when reseated,
    // across three consecutive toggles.
    18: 'Dust bag removed from the dock',

    // Mop pads taken off the robot: 0x15 while off, back to 0x00 once
    // refitted. Note `mop_state` stayed "installed" throughout, so it
    // tracks the mop module/bracket rather than the pads themselves —
    // pad presence has to come from this fault code, not that DP.
    21: 'Mop pads removed',

    // Observed during the dock's mop-washing routine — a normal automatic
    // step, not something wrong. Listed in _informationalFaults below so
    // it never raises the "needs attention" banner.
    22: 'Mop washing in progress',

    // Clean water tank out -> 0x18; reinserting cleared it to 0x00.
    24: 'Clean water tank removed',

    // Sewage tank toggled three times: out -> 0x19, in -> 0x00, every
    // time. The two tanks report genuinely distinct codes.
    25: 'Sewage tank removed',

    // The robot's internal dust bin (separate component from the dock's
    // dust bag, code 18) pulled out -> 0x2E.
    46: 'Dust bin removed from robot',

    // Confirmed persistent, not transient: stays at 0x0D the whole time
    // the dust bin sits installed (does not settle back to 0x00 like the
    // dock/self-check codes do). Functionally this is this device's
    // "dust bin present" status rather than a fault, so it's grouped with
    // the informational codes below even though it doesn't clear.
    13: 'Dust bin installed',
  };

  /// Codes that are normal automatic dock routine, not a problem — don't
  /// raise the "needs attention" banner for these.
  static const Set<int> _informationalCodes = <int>{22, 13};

  String get description => _confirmedFaults[code] ?? 'Robot fault (code $code)';

  /// Whether this code has a confirmed human-readable meaning, as opposed
  /// to being surfaced as a bare number.
  bool get isIdentified => _confirmedFaults.containsKey(code);

  /// Whether this should surface as an actionable error the user needs to
  /// address, as opposed to routine status.
  bool get needsAttention => !_informationalCodes.contains(code);

  @override
  bool operator ==(Object other) => other is TuyaFault && other.code == code;

  @override
  int get hashCode => code.hashCode;
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
          [const TuyaCommand(TuyaDpCodes.switchGo, true)],
        ],
      ResumeCleaningCommand() => [
          [const TuyaCommand(TuyaDpCodes.pause, false)],
        ],
      PauseCleaningCommand() => [
          [const TuyaCommand(TuyaDpCodes.pause, true)],
        ],
      StopCleaningCommand() => [
          [const TuyaCommand(TuyaDpCodes.switchGo, false)],
        ],
      ReturnToDockCommand() => [
          [const TuyaCommand(TuyaDpCodes.switchCharge, true)],
        ],
      SpotCleanCommand() => [
          [const TuyaCommand(TuyaDpCodes.mode, 'pose')],
          [const TuyaCommand(TuyaDpCodes.switchGo, true)],
        ],
      // This device's `mode` enum (smart/zone/pose) has no per-room
      // selection — room picking is app/map-side only, so this falls back
      // to a full smart clean.
      RoomCleanCommand() => [
          [const TuyaCommand(TuyaDpCodes.mode, 'smart')],
          [const TuyaCommand(TuyaDpCodes.switchGo, true)],
        ],
      ZoneCleanCommand() => [
          [const TuyaCommand(TuyaDpCodes.mode, 'zone')],
          [const TuyaCommand(TuyaDpCodes.switchGo, true)],
        ],
      CustomCleanCommand(:final power, :final waterFlow) => [
          [TuyaCommand(TuyaDpCodes.suction, _encodeSuction(power))],
          [TuyaCommand(TuyaDpCodes.waterOutput, _encodeWaterOutput(waterFlow))],
          [const TuyaCommand(TuyaDpCodes.switchGo, true)],
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
      // This robot DOES have a mop/water system — `water_output` is in its
      // real thing model, even though Tuya's v1.x specification omits it.
      SetWaterLevelCommand(:final level) => [
          [TuyaCommand(TuyaDpCodes.waterOutput, _encodeWaterOutput(level))],
        ],
      SetCleaningTypeCommand(:final type) => [
          [TuyaCommand(TuyaDpCodes.sweepMopMode, _encodeCleaningType(type))],
        ],
      SetCleaningPassesCommand(:final passes) => [
          [TuyaCommand(TuyaDpCodes.cleanTimes, passes.clamp(1, 2))],
        ],
      SetCarpetPreferenceCommand(:final preference) => [
          [TuyaCommand(TuyaDpCodes.carpetCleanPrefer, _encodeCarpetPreference(preference))],
        ],
      TriggerDustCollectionCommand() => [
          [const TuyaCommand(TuyaDpCodes.manualDustCollection, true)],
        ],
      TriggerMopWashCommand() => [
          [const TuyaCommand(TuyaDpCodes.wash, true)],
        ],
      TriggerMopDryCommand() => [
          [const TuyaCommand(TuyaDpCodes.manualAir, true)],
        ],
      SetAutoDustCollectionCommand(:final enabled) => [
          [TuyaCommand(TuyaDpCodes.autoDustCollection, enabled)],
        ],
      SetAutoMopDryCommand(:final enabled) => [
          [TuyaCommand(TuyaDpCodes.autoAir, enabled)],
        ],
      // No auto-wash toggle DP exists on this device — only the manual
      // trigger (`wash`) is exposed, unlike dust collection and drying
      // which both have a matching auto/manual pair.
      SetAutoMopWashCommand() => const [],
      ResetConsumableLifeCommand(:final type) => switch (type) {
          ConsumableType.mainBrush => [
              [const TuyaCommand(TuyaDpCodes.rollBrushLife, 0)],
            ],
          ConsumableType.sideBrush => [
              [const TuyaCommand(TuyaDpCodes.edgeBrushLife, 0)],
            ],
          ConsumableType.filter => [
              [const TuyaCommand(TuyaDpCodes.filterLife, 0)],
            ],
          ConsumableType.mopPad => [
              [const TuyaCommand(TuyaDpCodes.mopLife, 0)],
            ],
          // No battery/sensor life DP on this device.
          ConsumableType.battery || ConsumableType.sensor => const [],
        },
      SetVolumeCommand(:final percent) => [
          [TuyaCommand(TuyaDpCodes.volumeSet, percent.clamp(0, 100))],
        ],
      // `mode: select_room` is a real value on this device, but there is no
      // DP to specify which rooms — this triggers the mode only.
      SelectRoomCleanCommand() => [
          [const TuyaCommand(TuyaDpCodes.mode, 'select_room')],
          [const TuyaCommand(TuyaDpCodes.switchGo, true)],
        ],
      // No child-lock DP, and manual motor/pump/LED/room-naming controls
      // aren't part of this device's schema at all.
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
    bool? isMopAttached;
    List<TuyaFault> faults = const [];

    for (final Map<String, dynamic> point in points) {
      final String code = point['code'] as String;
      final Object? value = point['value'];

      switch (code) {
        case TuyaDpCodes.batteryPercentage:
        case TuyaDpCodes.electricityLeftV1:
          status = status.copyWith(batteryPercent: (value! as num) / 100.0);
        case TuyaDpCodes.cleanArea:
          status = status.copyWith(areaCleanedSqm: (value! as num).toDouble());
        case TuyaDpCodes.cleanTime:
          status = status.copyWith(cleaningElapsed: Duration(minutes: value! as int));
        case TuyaDpCodes.suction:
          status = status.copyWith(vacuumPower: _decodeSuction(value! as String));
        case TuyaDpCodes.waterOutput:
          status = status.copyWith(waterFlow: _decodeWaterOutput(value! as String));
        case TuyaDpCodes.rollBrushLife:
        case TuyaDpCodes.rollBrushV1:
          status = status.copyWith(
            consumables: _updateConsumable(status.consumables, ConsumableType.mainBrush, value! as num),
          );
        case TuyaDpCodes.edgeBrushLife:
        case TuyaDpCodes.edgeBrushV1:
          status = status.copyWith(
            consumables: _updateConsumable(status.consumables, ConsumableType.sideBrush, value! as num),
          );
        case TuyaDpCodes.filterLife:
        case TuyaDpCodes.filterV1:
          status = status.copyWith(
            consumables: _updateConsumable(status.consumables, ConsumableType.filter, value! as num),
          );
        case TuyaDpCodes.mopLife:
          status = status.copyWith(
            consumables: _updateConsumable(status.consumables, ConsumableType.mopPad, value! as num),
          );
        case TuyaDpCodes.mopState:
          isMopAttached = value == 'installed';
        case TuyaDpCodes.totalError:
          faults = decodeTotalError(value as String?);
        case TuyaDpCodes.sweepMopMode:
          status = status.copyWith(cleaningType: _decodeCleaningType(value! as String));
        case TuyaDpCodes.cleanTimes:
          status = status.copyWith(cleaningPasses: value! as int);
        case TuyaDpCodes.carpetCleanPrefer:
          status = status.copyWith(carpetPreference: _decodeCarpetPreference(value! as String));
        case TuyaDpCodes.autoDustCollection:
          status = status.copyWith(autoDustCollection: value! as bool);
        case TuyaDpCodes.autoAir:
          status = status.copyWith(autoMopDry: value! as bool);
        case TuyaDpCodes.volumeSet:
          status = status.copyWith(voiceVolume: value! as int);
        case TuyaDpCodes.switchGo:
        case TuyaDpCodes.powerGoV1:
          powerGo = value! as bool;
        case TuyaDpCodes.pause:
          pause = value! as bool;
        case TuyaDpCodes.switchCharge:
          switchCharge = value! as bool;
        case TuyaDpCodes.status:
          statusStr = value as String?;
        // Not a device DP — the backend appends this from Tuya's own
        // device record so a robot that's powered off or off-network
        // can be told apart from one that's simply idle. See
        // TuyaService.getDeviceStatus.
        case '__device_online':
          status = status.copyWith(deviceOnline: value as bool? ?? true);
      }
    }

    final ActivityState? resolvedActivity = _resolveActivity(
      powerGo: powerGo,
      pause: pause,
      switchCharge: switchCharge,
      statusStr: statusStr,
      previous: status.activity,
    );
    if (isMopAttached != null) {
      status = status.copyWith(isMopAttached: isMopAttached);
    }

    // `total_error` is the authoritative fault source — it carries the
    // actual fault numbers. `status: "fault"` only says *that* something
    // is wrong, so it's the fallback when the bitmap isn't present. Codes
    // like 22 (mop washing) are normal dock routine, not a problem, so
    // they're excluded from what raises the "needs attention" banner even
    // though they still show up in faultCodes/faultMessages.
    final bool hasActionableFault = faults.any((TuyaFault f) => f.needsAttention) ||
        (faults.isEmpty && resolvedActivity == ActivityState.error);
    status = status.copyWith(
      faultCodes: faults.map((TuyaFault f) => f.code).toList(),
      faultMessages: faults.map((TuyaFault f) => f.description).toList(),
      activeErrors: hasActionableFault ? const [RobotErrorCode.needsAttention] : const [],
    );

    if (resolvedActivity != null) {
      status = status.copyWith(
        activity: resolvedActivity,
        isCharging: resolvedActivity == ActivityState.charging || resolvedActivity == ActivityState.docked,
      );
    }

    return status.copyWith(connection: RobotConnectionState.connected, lastUpdated: DateTime.now());
  }

  /// `roll_brush_life`/`edge_brush_life`/`filter_life`/`mop_life` are NOT
  /// 0-100 percentages — confirmed against the device's real v2.0 thing
  /// model (`GET /v2.0/cloud/thing/{id}/model`), each is `{type: "value",
  /// unit: "min"}`: a running count of *minutes used*, with the type
  /// spec's `max` as the rated service life. Treating the raw value as a
  /// percentage (old code: `rawValue / 100`) meant every accessory clamped
  /// to 100% the moment usage passed 100 minutes and never moved again —
  /// this is why the values looked static. Rated lifetimes below are each
  /// DP's confirmed `max` from the thing model, not estimates.
  static List<Consumable> _updateConsumable(List<Consumable> consumables, ConsumableType type, num rawValue) {
    final int usedMinutes = rawValue.round();
    final int ratedLifetimeMinutes = switch (type) {
      ConsumableType.mainBrush => 18000, // roll_brush_life max
      ConsumableType.sideBrush => 9000, // edge_brush_life max
      ConsumableType.filter => 9000, // filter_life max
      ConsumableType.mopPad => 18000, // mop_life max
      _ => 0,
    };
    final double remainingPercent = ratedLifetimeMinutes == 0
        ? 0.0
        : (1 - (usedMinutes / ratedLifetimeMinutes)).clamp(0.0, 1.0);
    final Consumable updated = Consumable(
      type: type,
      remainingPercent: remainingPercent,
      ratedLifetimeMinutes: ratedLifetimeMinutes,
      usedMinutes: usedMinutes,
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
  /// The full 28-value range comes from the device's own v2.0 thing-model
  /// enum declaration — richer than what was previously derived only from
  /// v1.x's declared spec plus observed event logs. Unrecognized values
  /// fall back to whatever `power_go`/`pause`/`switch_charge` resolved
  /// rather than guessing.
  static ActivityState? _decodeStatusString(String value) => switch (value) {
        // Actively cleaning. `smart`/`zone`/`pose`/`select_room` mirror the
        // active mode; `relocation`/`goto_pos`/`mapping` are the robot
        // moving/re-localising mid-run, still underway.
        'smart' ||
        'zone' ||
        'pose' ||
        'select_room' ||
        'cleaning' ||
        'zone_clean' ||
        'part_clean' ||
        'goto_pos' ||
        'pos_arrived' ||
        'relocation' ||
        'mapping' ||
        'mapping_done' ||
        'manual_control' ||
        'quick_mapping' =>
          ActivityState.cleaning,

        'paused' || 'pos_unarrive' || 'paused_backtowashmop' => ActivityState.paused,

        'goto_charge' ||
        'relocation_recharge' ||
        'backtowashmop' ||
        'breakpoint_charging' =>
          ActivityState.returningToDock,

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
        'seek_dust_bucket' ||
        'breakpoint_washing' =>
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

  /// Decodes the `total_error` DP into the active fault numbers.
  ///
  /// Per the device's own thing-model definition: hexadecimal, one byte
  /// per active fault (`0102041E` = faults 1, 2, 4 and 30 simultaneously),
  /// `00` = no fault / fault cleared. Tuya delivers the raw bytes
  /// base64-encoded over the API.
  static List<TuyaFault> decodeTotalError(String? base64Value) {
    if (base64Value == null || base64Value.isEmpty) return const [];

    List<int> bytes;
    try {
      bytes = base64Decode(base64Value);
    } on FormatException {
      return const [];
    }

    // Zero bytes are padding / the explicit "no fault" marker.
    return bytes.where((int b) => b != 0).map(TuyaFault.new).toList();
  }

  static WaterFlow _decodeWaterOutput(String value) => switch (value) {
        'closed' => WaterFlow.off,
        'low' => WaterFlow.low,
        'middle' => WaterFlow.medium,
        'high' => WaterFlow.high,
        _ => WaterFlow.off,
      };

  static String _encodeWaterOutput(WaterFlow flow) => switch (flow) {
        WaterFlow.off => 'closed',
        WaterFlow.low => 'low',
        WaterFlow.medium => 'middle',
        WaterFlow.high || WaterFlow.ultra => 'high',
      };

  /// The v2.0 model exposes 4 usable levels (`closed` is "off", not a
  /// cleaning preference, so it's never sent from a power selector):
  /// gentle | normal | strong | max.
  static String _encodeSuction(VacuumPower power) => switch (power) {
        VacuumPower.silent => 'gentle',
        VacuumPower.eco => 'gentle',
        VacuumPower.standard => 'normal',
        VacuumPower.strong => 'strong',
        VacuumPower.turbo => 'max',
        VacuumPower.maximum => 'max',
        VacuumPower.custom => 'normal',
      };

  static VacuumPower _decodeSuction(String value) => switch (value) {
        'gentle' => VacuumPower.eco,
        'normal' => VacuumPower.standard,
        'strong' => VacuumPower.strong,
        'max' => VacuumPower.maximum,
        _ => VacuumPower.standard,
      };

  static String _encodeCleaningType(CleaningType type) => switch (type) {
        CleaningType.vacuum => 'only_sweep',
        CleaningType.mop => 'only_mop',
        CleaningType.vacuumAndMop => 'both_work',
        CleaningType.mopAfterVacuum => 'clean_before_mop',
      };

  static CleaningType _decodeCleaningType(String value) => switch (value) {
        'only_sweep' => CleaningType.vacuum,
        'only_mop' => CleaningType.mop,
        'both_work' => CleaningType.vacuumAndMop,
        'clean_before_mop' => CleaningType.mopAfterVacuum,
        _ => CleaningType.vacuumAndMop,
      };

  static String _encodeCarpetPreference(CarpetPreference preference) => switch (preference) {
        CarpetPreference.adaptive => 'adaptive',
        CarpetPreference.avoid => 'evade',
        CarpetPreference.ignore => 'ignore',
      };

  static CarpetPreference _decodeCarpetPreference(String value) => switch (value) {
        'adaptive' => CarpetPreference.adaptive,
        'evade' => CarpetPreference.avoid,
        'ignore' => CarpetPreference.ignore,
        _ => CarpetPreference.adaptive,
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

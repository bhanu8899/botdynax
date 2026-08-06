import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/robot_fleet_repository_impl.dart';
import '../../data/repositories/robot_repository_impl.dart';
import '../../data/transport/tuya_transport.dart';
import '../../domain/entities/map_data.dart';
import '../../domain/entities/robot_command.dart';
import '../../domain/entities/robot_enums.dart';
import '../../domain/entities/robot_status.dart';
import '../../domain/repositories/robot_fleet_repository.dart';
import '../../domain/repositories/robot_repository.dart';
import '../../domain/transport/robot_transport.dart';
import 'auth_providers.dart';

/// The real, live-connected robot: the user's Milagrow iMap Max W300,
/// reached through Tuya Cloud (Smart Life ecosystem) rather than
/// BotDyNax's own BLE/WiFi/MQTT firmware.
abstract final class MilagrowW300 {
  // A stable identity for the *backend fleet record*, independent of the
  // Tuya device id -- that id changes every time this device
  // re-provisions with Tuya (observed after what looked like a routine
  // reboot; the old id starts 404ing "device does not exist" afterward).
  // This one const stays fixed regardless, so `ensureRegistered` below
  // always resolves to the same backend robot row instead of silently
  // creating a new one (and colliding with the old row's still-unique
  // tuyaDeviceId) every time Tuya reassigns the device id.
  static const String serialNumber = 'milagrow-w300-primary';

  // Tuya's real product id (confirmed via `/v2.0/cloud/thing/{id}` --
  // NOT the human-readable model string "LW41MF") -- used to look up
  // whichever device id is currently live, via
  // TuyaService.discoverDeviceIdByProduct / POST /tuya/robots/:id/link-auto.
  static const String productId = 'ajfqwthgagxilcki';
  static const String name = 'iMap Max W300';
  static const String model = 'Milagrow iMap Max W300 (LW41MF)';
}

final Provider<RobotFleetRepository> robotFleetRepositoryProvider = Provider<RobotFleetRepository>((Ref ref) {
  return RobotFleetRepositoryImpl(dio: ref.watch(apiClientProvider).dio);
});

/// The active [RobotTransport]. Swap this for [BLETransport], [WifiTransport],
/// or [MQTTTransport] to move a given robot off Tuya Cloud onto BotDyNax's
/// own firmware.
final Provider<RobotTransport> robotTransportProvider = Provider<RobotTransport>((Ref ref) {
  final RobotTransport transport = TuyaTransport(dio: ref.watch(apiClientProvider).dio);
  ref.onDispose(() {
    unawaited(transport.dispose());
  });
  return transport;
});

final Provider<RobotRepository> robotRepositoryProvider = Provider<RobotRepository>((Ref ref) {
  return RobotRepositoryImpl(ref.watch(robotTransportProvider));
});

/// Live, reactive robot status — the single source of truth every status
/// widget across the app should watch.
final StreamProvider<RobotStatus> robotStatusProvider = StreamProvider<RobotStatus>((Ref ref) {
  return ref.watch(robotRepositoryProvider).watchStatus();
});

/// Live, reactive SLAM map for the currently paired robot.
final StreamProvider<CleaningMap> robotMapProvider = StreamProvider<CleaningMap>((Ref ref) {
  return ref.watch(robotRepositoryProvider).watchMap();
});

/// Discrete robot-pushed events (cleaning finished, errors, OTA available).
final StreamProvider<RobotEvent> robotEventsProvider = StreamProvider<RobotEvent>((Ref ref) {
  return ref.watch(robotRepositoryProvider).watchEvents();
});

final Provider<RobotController> robotControllerProvider = Provider<RobotController>((Ref ref) {
  return RobotController(ref);
});

/// Every user-facing action in the app funnels through this controller.
/// Screens never call [RobotRepository] or a transport directly.
class RobotController {
  RobotController(this._ref);

  final Ref _ref;

  RobotRepository get _repository => _ref.read(robotRepositoryProvider);

  /// Pairs the user's real Milagrow iMap Max W300. [TuyaTransport.connect]
  /// takes a *backend* robot id (it resolves that to the Tuya device id
  /// itself, server-side), so this registers/links the backend fleet
  /// record first and then connects with the id that comes back — unlike
  /// BLE/WiFi/MQTT transports, which connect with a transport-local id
  /// directly.
  Future<void> pairDefaultRobot() async {
    final RobotFleetRepository fleet = _ref.read(robotFleetRepositoryProvider);
    final String robotId = await fleet.ensureRegistered(
      serialNumber: MilagrowW300.serialNumber,
      name: MilagrowW300.name,
      model: MilagrowW300.model,
    );
    await fleet.linkTuyaDeviceAuto(robotId: robotId, productId: MilagrowW300.productId);
    await _repository.pair(robotId);
  }

  Future<void> unpair() => _repository.unpair();

  Future<void> startCleaning({CleaningMode mode = CleaningMode.auto}) =>
      _repository.sendCommand(StartCleaningCommand(mode: mode));

  Future<void> pause() => _repository.sendCommand(const PauseCleaningCommand());

  Future<void> resume() => _repository.sendCommand(const ResumeCleaningCommand());

  Future<void> stop() => _repository.sendCommand(const StopCleaningCommand());

  Future<void> returnToDock() => _repository.sendCommand(const ReturnToDockCommand());

  Future<void> spotClean() => _repository.sendCommand(const SpotCleanCommand());

  Future<void> roomClean(List<String> roomIds) => _repository.sendCommand(RoomCleanCommand(roomIds));

  Future<void> zoneClean(List<String> zoneIds) => _repository.sendCommand(ZoneCleanCommand(zoneIds));

  Future<void> customClean({
    required List<String> roomIds,
    required VacuumPower power,
    required WaterFlow waterFlow,
  }) =>
      _repository.sendCommand(CustomCleanCommand(roomIds: roomIds, power: power, waterFlow: waterFlow));

  Future<void> setVacuumPower(VacuumPower power, {double? customLevel}) =>
      _repository.sendCommand(SetVacuumPowerCommand(power, customLevel: customLevel));

  Future<void> setWaterLevel(WaterFlow level, {MopPattern? pattern}) =>
      _repository.sendCommand(SetWaterLevelCommand(level, pattern: pattern));

  Future<void> findRobot() => _repository.sendCommand(const FindRobotCommand());

  Future<void> emergencyStop() => _repository.sendCommand(const EmergencyStopCommand());

  Future<void> setChildLock(bool enabled) => _repository.sendCommand(SetChildLockCommand(enabled));

  Future<void> renameRoom({required String roomId, required String name}) =>
      _repository.sendCommand(RenameRoomCommand(roomId: roomId, name: name));

  Future<void> drive({required double linear, required double angular}) =>
      _repository.sendCommand(DriveCommand(linear: linear, angular: angular));

  Future<void> setVacuumMotor(bool enabled) => _repository.sendCommand(SetVacuumMotorCommand(enabled));

  Future<void> setWaterPump(bool enabled) => _repository.sendCommand(SetWaterPumpCommand(enabled));

  Future<void> setLed(bool enabled) => _repository.sendCommand(SetLedCommand(enabled));

  Future<void> factoryReset() => _repository.sendCommand(const FactoryResetCommand());

  Future<void> restart() => _repository.sendCommand(const RestartRobotCommand());

  Future<void> setCleaningType(CleaningType type) =>
      _repository.sendCommand(SetCleaningTypeCommand(type));

  Future<void> setCleaningPasses(int passes) =>
      _repository.sendCommand(SetCleaningPassesCommand(passes));

  Future<void> setCarpetPreference(CarpetPreference preference) =>
      _repository.sendCommand(SetCarpetPreferenceCommand(preference));

  Future<void> triggerDustCollection() => _repository.sendCommand(const TriggerDustCollectionCommand());

  Future<void> triggerMopWash() => _repository.sendCommand(const TriggerMopWashCommand());

  Future<void> triggerMopDry() => _repository.sendCommand(const TriggerMopDryCommand());

  Future<void> setAutoDustCollection(bool enabled) =>
      _repository.sendCommand(SetAutoDustCollectionCommand(enabled));

  Future<void> setAutoMopDry(bool enabled) => _repository.sendCommand(SetAutoMopDryCommand(enabled));

  Future<void> resetConsumableLife(ConsumableType type) =>
      _repository.sendCommand(ResetConsumableLifeCommand(type));

  Future<void> selectRoomClean() => _repository.sendCommand(const SelectRoomCleanCommand());

  Future<void> setVolume(int percent) => _repository.sendCommand(SetVolumeCommand(percent));
}

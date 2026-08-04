import 'dart:async';
import 'dart:math' as math;

import '../../domain/entities/consumable.dart';
import '../../domain/entities/map_data.dart';
import '../../domain/entities/robot_command.dart';
import '../../domain/entities/robot_enums.dart';
import '../../domain/entities/robot_status.dart';
import '../../domain/transport/robot_transport.dart';

/// Fully reactive fake robot used for development, demos, and UI testing
/// without real BotDyNax hardware. Every screen in this app should look and
/// behave exactly as it will against a real robot when driven by this class.
class SimulatorTransport implements RobotTransport {
  SimulatorTransport({String robotId = 'SIM-VACUUM-001', String name = 'BotDyNax Vacuum'})
      : _robotId = robotId,
        _status = RobotStatus.initial(robotId, name).copyWith(
          firmwareVersion: '1.4.2',
          consumables: _initialConsumables,
          batteryPercent: 0.62,
        ),
        _map = _initialMap;

  static const List<Consumable> _initialConsumables = [
    Consumable(type: ConsumableType.mainBrush, remainingPercent: 0.78, ratedLifetimeMinutes: 18000, usedMinutes: 3960),
    Consumable(type: ConsumableType.sideBrush, remainingPercent: 0.64, ratedLifetimeMinutes: 12000, usedMinutes: 4320),
    Consumable(type: ConsumableType.filter, remainingPercent: 0.41, ratedLifetimeMinutes: 9000, usedMinutes: 5310),
    Consumable(type: ConsumableType.mopPad, remainingPercent: 0.85, ratedLifetimeMinutes: 6000, usedMinutes: 900),
    Consumable(type: ConsumableType.sensor, remainingPercent: 0.93, ratedLifetimeMinutes: 24000, usedMinutes: 1680),
  ];

  static final CleaningMap _initialMap = CleaningMap.empty('map-home-floor-1').copyWith(
    name: 'Home',
    dockPose: const Pose(position: MapPoint(0.4, 0.4), headingRadians: 0),
    robotPose: const Pose(position: MapPoint(0.4, 0.4), headingRadians: 0),
    rooms: const [
      RoomZone(
        id: 'room-living',
        name: 'Living Room',
        polygon: [MapPoint(0, 0), MapPoint(5.2, 0), MapPoint(5.2, 4.0), MapPoint(0, 4.0)],
        colorValue: 0xFF22E6C6,
        floorIndex: 0,
        cleaningOrder: 1,
      ),
      RoomZone(
        id: 'room-kitchen',
        name: 'Kitchen',
        polygon: [MapPoint(5.4, 0), MapPoint(8.6, 0), MapPoint(8.6, 3.2), MapPoint(5.4, 3.2)],
        colorValue: 0xFF7C5CFF,
        floorIndex: 0,
        cleaningOrder: 2,
      ),
      RoomZone(
        id: 'room-bedroom',
        name: 'Bedroom',
        polygon: [MapPoint(0, 4.2), MapPoint(4.4, 4.2), MapPoint(4.4, 7.6), MapPoint(0, 7.6)],
        colorValue: 0xFF3D8BFF,
        floorIndex: 0,
        cleaningOrder: 3,
      ),
      RoomZone(
        id: 'room-hallway',
        name: 'Hallway',
        polygon: [MapPoint(4.6, 3.4), MapPoint(8.6, 3.4), MapPoint(8.6, 7.6), MapPoint(4.6, 7.6)],
        colorValue: 0xFFFFB020,
        floorIndex: 0,
        cleaningOrder: 4,
      ),
    ],
    carpetAreas: const [
      CarpetArea(id: 'carpet-living', polygon: [MapPoint(1.0, 1.0), MapPoint(3.4, 1.0), MapPoint(3.4, 3.0), MapPoint(1.0, 3.0)]),
    ],
  );

  final String _robotId;
  final math.Random _random = math.Random();

  RobotStatus _status;
  CleaningMap _map;
  bool _connected = false;
  Timer? _ticker;

  final StreamController<RobotStatus> _statusController = StreamController<RobotStatus>.broadcast();
  final StreamController<CleaningMap> _mapController = StreamController<CleaningMap>.broadcast();
  final StreamController<RobotEvent> _eventController = StreamController<RobotEvent>.broadcast();

  static const Duration _tick = Duration(seconds: 1);
  static const double _batteryDrainPerTickCleaning = 0.0028;
  static const double _batteryChargePerTickDocked = 0.02;
  static const double _dustBinFillPerTickCleaning = 0.0009;
  static const double _waterTankDrainPerTickMopping = 0.0011;

  @override
  bool get isConnected => _connected;

  @override
  Stream<DiscoveredRobot> scan({Duration timeout = const Duration(seconds: 10)}) async* {
    yield DiscoveredRobot(id: _robotId, name: _status.name, signalStrength: -42, model: 'BotDyNax Vacuum X1');
    await Future<void>.delayed(const Duration(milliseconds: 600));
    yield const DiscoveredRobot(
      id: 'SIM-VACUUM-002',
      name: 'BotDyNax Vacuum (Bedroom)',
      signalStrength: -61,
      model: 'BotDyNax Vacuum X1',
    );
  }

  @override
  Future<void> connect(String robotId) async {
    await Future<void>.delayed(const Duration(milliseconds: 900));
    _connected = true;
    _status = _status.copyWith(
      connection: RobotConnectionState.connected,
      activity: ActivityState.docked,
      wifiSignal: const SignalStrength(bars: 4, rssi: -48),
      bleSignal: const SignalStrength(bars: 3, rssi: -55),
      lastUpdated: DateTime.now(),
    );
    _statusController.add(_status);
    _mapController.add(_map);
    _ticker?.cancel();
    _ticker = Timer.periodic(_tick, (_) => _onTick());
  }

  @override
  Future<void> disconnect() async {
    _ticker?.cancel();
    _ticker = null;
    _connected = false;
    _status = _status.copyWith(connection: RobotConnectionState.disconnected, lastUpdated: DateTime.now());
    _statusController.add(_status);
  }

  @override
  Future<void> write(List<int> bytes) async {}

  @override
  Future<List<int>> read() async => const [];

  @override
  Stream<List<int>> subscribe(String channel) => const Stream<List<int>>.empty();

  @override
  Future<void> sendCommand(RobotCommand command) async {
    switch (command) {
      case StartCleaningCommand(:final mode):
        _status = _status.copyWith(
          activity: ActivityState.cleaning,
          isCharging: false,
          currentTask: _labelForMode(mode),
          currentRoom: _map.rooms.isNotEmpty ? _map.rooms.first.name : null,
          cleaningElapsed: Duration.zero,
          cleaningRemaining: const Duration(minutes: 42),
          areaCleanedSqm: 0,
        );
        _eventController.add(const CleaningStartedEvent());
      case PauseCleaningCommand():
        _status = _status.copyWith(activity: ActivityState.paused);
      case ResumeCleaningCommand():
        _status = _status.copyWith(activity: ActivityState.cleaning);
      case StopCleaningCommand():
        _status = _status.copyWith(
          activity: ActivityState.idle,
          clearCurrentRoom: true,
          clearCurrentTask: true,
        );
      case ReturnToDockCommand():
        _status = _status.copyWith(activity: ActivityState.returningToDock, clearCurrentTask: true);
      case SpotCleanCommand():
        _status = _status.copyWith(activity: ActivityState.cleaning, currentTask: 'Spot Clean');
      case RoomCleanCommand(:final roomIds):
        _status = _status.copyWith(
          activity: ActivityState.cleaning,
          currentTask: 'Room Clean',
          currentRoom: _roomName(roomIds.isNotEmpty ? roomIds.first : null),
        );
      case ZoneCleanCommand():
        _status = _status.copyWith(activity: ActivityState.cleaning, currentTask: 'Zone Clean');
      case CustomCleanCommand(:final power, :final waterFlow):
        _status = _status.copyWith(
          activity: ActivityState.cleaning,
          currentTask: 'Custom Clean',
          vacuumPower: power,
          waterFlow: waterFlow,
        );
      case SetVacuumPowerCommand(:final power):
        _status = _status.copyWith(vacuumPower: power);
      case SetWaterLevelCommand(:final level):
        _status = _status.copyWith(waterFlow: level);
      case SetCleaningTypeCommand(:final type):
        _status = _status.copyWith(cleaningType: type);
      case SetCleaningPassesCommand(:final passes):
        _status = _status.copyWith(cleaningPasses: passes);
      case SetCarpetPreferenceCommand(:final preference):
        _status = _status.copyWith(carpetPreference: preference);
      case SetAutoDustCollectionCommand(:final enabled):
        _status = _status.copyWith(autoDustCollection: enabled);
      case SetAutoMopWashCommand(:final enabled):
        _status = _status.copyWith(autoMopWash: enabled);
      case SetAutoMopDryCommand(:final enabled):
        _status = _status.copyWith(autoMopDry: enabled);
      case TriggerDustCollectionCommand():
      case TriggerMopWashCommand():
      case TriggerMopDryCommand():
      case SelectRoomCleanCommand():
        break;
      case SetVolumeCommand(:final percent):
        _status = _status.copyWith(voiceVolume: percent);
      case ResetConsumableLifeCommand(:final type):
        _status = _status.copyWith(
          consumables: [
            for (final Consumable c in _status.consumables)
              if (c.type == type) c.copyWith(remainingPercent: 1.0, usedMinutes: 0) else c,
          ],
        );
      case FindRobotCommand():
        _eventController.add(const CleaningStartedEvent());
      case EmergencyStopCommand():
        _status = _status.copyWith(activity: ActivityState.idle, clearCurrentTask: true);
      case SetChildLockCommand(:final enabled):
        _status = _status.copyWith(isChildLockOn: enabled);
      case RenameRoomCommand(:final roomId, :final name):
        _map = _map.copyWith(
          rooms: [
            for (final RoomZone room in _map.rooms)
              if (room.id == roomId) room.copyWith(name: name) else room,
          ],
        );
        _mapController.add(_map);
      case StartOtaCommand():
      case RestartRobotCommand():
      case FactoryResetCommand():
      case GetBatteryCommand():
      case GetMapCommand():
      case GetStatusCommand():
      case GetErrorsCommand():
      case GetLogsCommand():
      case SetVacuumMotorCommand():
      case SetWaterPumpCommand():
      case SetLedCommand():
        break;
      case DriveCommand(:final linear, :final angular):
        _applyManualDrive(linear, angular);
    }
    _status = _status.copyWith(lastUpdated: DateTime.now());
    _statusController.add(_status);
  }

  /// Nudges the robot's pose in response to a joystick drive command, so
  /// the Remote Control screen gets real, immediate visual feedback on the
  /// Live Map rather than a silently-acknowledged no-op.
  void _applyManualDrive(double linear, double angular) {
    const double linearStepMeters = 0.18;
    const double angularStepRadians = 0.35;

    final double heading = _map.robotPose.headingRadians + angular * angularStepRadians;
    final MapPoint position = MapPoint(
      (_map.robotPose.position.x + math.cos(heading) * linear * linearStepMeters).clamp(0.1, 8.4),
      (_map.robotPose.position.y + math.sin(heading) * linear * linearStepMeters).clamp(0.1, 7.4),
    );

    _map = _map.copyWith(robotPose: Pose(position: position, headingRadians: heading));
    _mapController.add(_map);
  }

  @override
  Stream<RobotStatus> receiveStatus() async* {
    yield _status;
    yield* _statusController.stream;
  }

  @override
  Stream<CleaningMap> receiveMap() async* {
    yield _map;
    yield* _mapController.stream;
  }

  @override
  Stream<RobotEvent> receiveEvents() => _eventController.stream;

  @override
  Future<void> dispose() async {
    _ticker?.cancel();
    await _statusController.close();
    await _mapController.close();
    await _eventController.close();
  }

  void _onTick() {
    switch (_status.activity) {
      case ActivityState.cleaning:
        _simulateCleaningTick();
      case ActivityState.returningToDock:
        _simulateReturnTick();
      case ActivityState.docked:
      case ActivityState.charging:
      case ActivityState.idle:
        _simulateIdleTick();
      case ActivityState.paused:
      case ActivityState.error:
        break;
    }
    _statusController.add(_status);
    _mapController.add(_map);
  }

  void _simulateCleaningTick() {
    final Duration remaining = _status.cleaningRemaining - _tick;
    final double battery = (_status.batteryPercent - _batteryDrainPerTickCleaning).clamp(0.0, 1.0);

    final Pose newPose = _wanderPose(_map.robotPose);
    final List<MapPoint> newPath = [..._map.path, newPose.position];
    if (newPath.length > 600) {
      newPath.removeRange(0, newPath.length - 600);
    }
    _map = _map.copyWith(robotPose: newPose, path: newPath, updatedAt: DateTime.now());

    if (remaining <= Duration.zero || battery <= 0.05) {
      _status = _status.copyWith(
        activity: ActivityState.returningToDock,
        cleaningElapsed: _status.cleaningElapsed + _tick,
        cleaningRemaining: Duration.zero,
        batteryPercent: battery,
      );
      _eventController.add(
        CleaningCompletedEvent(areaCleanedSqm: _status.areaCleanedSqm, duration: _status.cleaningElapsed),
      );
      return;
    }

    final bool isMopping = _status.waterFlow != WaterFlow.off;
    _status = _status.copyWith(
      cleaningElapsed: _status.cleaningElapsed + _tick,
      cleaningRemaining: remaining,
      batteryPercent: battery,
      areaCleanedSqm: _status.areaCleanedSqm + 0.03,
      dustBinPercent: (_status.dustBinPercent + _dustBinFillPerTickCleaning).clamp(0.0, 1.0),
      waterTankPercent: isMopping
          ? (_status.waterTankPercent - _waterTankDrainPerTickMopping).clamp(0.0, 1.0)
          : _status.waterTankPercent,
    );
  }

  void _simulateReturnTick() {
    final MapPoint delta = MapPoint(
      _map.dockPose.position.x - _map.robotPose.position.x,
      _map.dockPose.position.y - _map.robotPose.position.y,
    );
    final double distance = math.sqrt(delta.x * delta.x + delta.y * delta.y);

    if (distance < 0.15) {
      _map = _map.copyWith(robotPose: _map.dockPose);
      _status = _status.copyWith(activity: ActivityState.docked, isCharging: true);
      return;
    }

    const double stepMeters = 0.35;
    final double ratio = (stepMeters / distance).clamp(0.0, 1.0);
    final MapPoint step = MapPoint(_map.robotPose.position.x + delta.x * ratio, _map.robotPose.position.y + delta.y * ratio);
    _map = _map.copyWith(robotPose: Pose(position: step, headingRadians: math.atan2(delta.y, delta.x)));
  }

  void _simulateIdleTick() {
    if (_status.activity == ActivityState.docked && _status.batteryPercent < 1.0) {
      _status = _status.copyWith(
        batteryPercent: (_status.batteryPercent + _batteryChargePerTickDocked).clamp(0.0, 1.0),
        isCharging: true,
      );
    }
  }

  Pose _wanderPose(Pose current) {
    final double heading = current.headingRadians + (_random.nextDouble() - 0.5) * 0.6;
    const double stepMeters = 0.12;
    final MapPoint next = MapPoint(
      (current.position.x + math.cos(heading) * stepMeters).clamp(0.1, 8.4),
      (current.position.y + math.sin(heading) * stepMeters).clamp(0.1, 7.4),
    );
    return Pose(position: next, headingRadians: heading);
  }

  String _labelForMode(CleaningMode mode) => switch (mode) {
        CleaningMode.auto => 'Auto Clean',
        CleaningMode.room => 'Room Clean',
        CleaningMode.zone => 'Zone Clean',
        CleaningMode.spot => 'Spot Clean',
        CleaningMode.custom => 'Custom Clean',
      };

  String? _roomName(String? roomId) {
    if (roomId == null) return null;
    for (final RoomZone room in _map.rooms) {
      if (room.id == roomId) return room.name;
    }
    return null;
  }
}

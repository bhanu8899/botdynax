import '../../domain/entities/map_data.dart';
import '../../domain/entities/robot_command.dart';
import '../../domain/entities/robot_status.dart';
import '../../domain/repositories/robot_repository.dart';
import '../../domain/transport/robot_transport.dart';

/// Adapts whichever [RobotTransport] is currently active to the domain's
/// [RobotRepository] contract. This is the only class allowed to hold a
/// direct reference to a [RobotTransport].
class RobotRepositoryImpl implements RobotRepository {
  RobotRepositoryImpl(this._transport);

  final RobotTransport _transport;

  @override
  Stream<DiscoveredRobot> discoverRobots() => _transport.scan();

  @override
  Future<void> pair(String robotId) => _transport.connect(robotId);

  @override
  Future<void> unpair() => _transport.disconnect();

  @override
  Future<void> sendCommand(RobotCommand command) => _transport.sendCommand(command);

  @override
  Stream<RobotStatus> watchStatus() => _transport.receiveStatus();

  @override
  Stream<CleaningMap> watchMap() => _transport.receiveMap();

  @override
  Stream<RobotEvent> watchEvents() => _transport.receiveEvents();
}

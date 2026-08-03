import '../entities/map_data.dart';
import '../entities/robot_command.dart';
import '../entities/robot_status.dart';
import '../transport/robot_transport.dart';

/// Application-facing gateway to "the currently paired robot". Decouples
/// presentation/state layers from the concrete [RobotTransport] in use.
abstract class RobotRepository {
  Stream<DiscoveredRobot> discoverRobots();

  Future<void> pair(String robotId);

  Future<void> unpair();

  Future<void> sendCommand(RobotCommand command);

  Stream<RobotStatus> watchStatus();

  Stream<CleaningMap> watchMap();

  Stream<RobotEvent> watchEvents();
}

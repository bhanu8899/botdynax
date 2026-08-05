import '../entities/map_data.dart';
import '../entities/robot_command.dart';
import '../entities/robot_status.dart';

/// A device discovered during [RobotTransport.scan], before pairing.
class DiscoveredRobot {
  const DiscoveredRobot({
    required this.id,
    required this.name,
    required this.signalStrength,
    required this.model,
  });

  final String id;
  final String name;
  final int signalStrength;
  final String model;
}

/// Out-of-band events a robot can push that aren't part of the regular
/// status stream (errors, cleaning finished, dust bin full, etc).
sealed class RobotEvent {
  const RobotEvent();
}

class CleaningStartedEvent extends RobotEvent {
  const CleaningStartedEvent();
}

class CleaningCompletedEvent extends RobotEvent {
  const CleaningCompletedEvent({
    required this.areaCleanedSqm,
    required this.duration,
    required this.batteryUsedPercent,
    required this.errors,
  });
  final double areaCleanedSqm;
  final Duration duration;

  /// Battery percentage points consumed over the session (start - end). 0
  /// when the transport has no way to know the starting battery level.
  final double batteryUsedPercent;

  /// Fault messages observed at any point during the session.
  final List<String> errors;
}

class RobotErrorEvent extends RobotEvent {
  const RobotErrorEvent(this.code);
  final Object code;
}

class FirmwareUpdateAvailableEvent extends RobotEvent {
  const FirmwareUpdateAvailableEvent(this.version);
  final String version;
}

/// The single contract every physical/virtual link to a robot must satisfy.
///
/// UI and application state (see `RobotController`) never talk to BLE, WiFi,
/// or MQTT clients directly — they only depend on this interface. Swapping
/// [BLETransport], [WifiTransport], or [MQTTTransport] in for
/// [SimulatorTransport] is the only change required to connect this app to
/// real BotDyNax firmware.
abstract class RobotTransport {
  /// True once [connect] has resolved and the link is live.
  bool get isConnected;

  /// Discover nearby/reachable robots before pairing. Terminates the
  /// returned stream when scanning stops (timeout or [connect] called).
  Stream<DiscoveredRobot> scan({Duration timeout = const Duration(seconds: 10)});

  Future<void> connect(String robotId);

  Future<void> disconnect();

  /// Low-level write, exposed for transport-specific debugging/dev tools.
  /// Application code should prefer [sendCommand].
  Future<void> write(List<int> bytes);

  /// Low-level read, exposed for transport-specific debugging/dev tools.
  Future<List<int>> read();

  /// Subscribe to a raw characteristic/topic; used internally by transport
  /// implementations to build the typed streams below.
  Stream<List<int>> subscribe(String channel);

  Future<void> sendCommand(RobotCommand command);

  /// Continuous, reactive robot status. Emits immediately on subscribe with
  /// the last known status, then on every change.
  Stream<RobotStatus> receiveStatus();

  /// Continuous, reactive SLAM map updates.
  Stream<CleaningMap> receiveMap();

  /// Discrete robot-pushed events (see [RobotEvent]).
  Stream<RobotEvent> receiveEvents();

  /// Releases all resources (streams, sockets, subscriptions).
  Future<void> dispose();
}

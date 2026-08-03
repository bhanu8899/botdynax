import 'dart:async';
import 'dart:convert';

import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

import '../../domain/entities/map_data.dart';
import '../../domain/entities/robot_command.dart';
import '../../domain/entities/robot_status.dart';
import '../../domain/transport/robot_transport.dart';
import 'robot_wire_protocol.dart';

/// MQTT broker connection + topic layout.
///
/// *** REPLACE WITH YOUR REAL BROKER HOST AND TOPIC NAMES ***
/// Points at the local Mosquitto broker started alongside the BotDyNax
/// backend (see `/backend`) by default. Connection lifecycle, subscription
/// plumbing, and JSON encode/decode below are complete.
abstract final class MqttTopics {
  static const String brokerHost = 'localhost';
  static const int brokerPort = 1883;

  static String status(String robotId) => 'botdynax/$robotId/status';
  static String map(String robotId) => 'botdynax/$robotId/map';
  static String events(String robotId) => 'botdynax/$robotId/events';
  static String commands(String robotId) => 'botdynax/$robotId/commands';
}

/// MQTT transport: the primary always-connected link once a robot is on the
/// home network and paired with the cloud backend, favored for its low
/// overhead push model over polling REST.
class MQTTTransport implements RobotTransport {
  MqttServerClient? _client;
  String? _robotId;

  RobotStatus _lastStatus = RobotStatus.initial('unknown', 'BotDyNax Robot');
  CleaningMap _lastMap = CleaningMap.empty('unknown');

  final StreamController<RobotStatus> _statusController = StreamController<RobotStatus>.broadcast();
  final StreamController<CleaningMap> _mapController = StreamController<CleaningMap>.broadcast();
  final StreamController<RobotEvent> _eventController = StreamController<RobotEvent>.broadcast();

  StreamSubscription<List<MqttReceivedMessage<MqttMessage>>>? _updatesSub;

  @override
  bool get isConnected =>
      _client?.connectionStatus?.state == MqttConnectionState.connected;

  @override
  Stream<DiscoveredRobot> scan({Duration timeout = const Duration(seconds: 10)}) {
    // MQTT is a paired-device transport; discovery happens over BLE/WiFi.
    return const Stream<DiscoveredRobot>.empty();
  }

  @override
  Future<void> connect(String robotId) async {
    _robotId = robotId;
    final MqttServerClient client = MqttServerClient.withPort(
      MqttTopics.brokerHost,
      'botdynax-app-$robotId',
      MqttTopics.brokerPort,
    );
    client.logging(on: false);
    client.keepAlivePeriod = 30;
    client.autoReconnect = true;
    client.connectionMessage = MqttConnectMessage().withClientIdentifier('botdynax-app-$robotId').startClean();

    await client.connect();
    _client = client;

    client.subscribe(MqttTopics.status(robotId), MqttQos.atLeastOnce);
    client.subscribe(MqttTopics.map(robotId), MqttQos.atLeastOnce);
    client.subscribe(MqttTopics.events(robotId), MqttQos.atLeastOnce);

    await _updatesSub?.cancel();
    _updatesSub = client.updates?.listen(_handleMessages);
  }

  void _handleMessages(List<MqttReceivedMessage<MqttMessage>> messages) {
    for (final MqttReceivedMessage<MqttMessage> message in messages) {
      final MqttPublishMessage publish = message.payload as MqttPublishMessage;
      final String payload = MqttPublishPayload.bytesToStringAsString(publish.payload.message);
      final Map<String, dynamic> json = jsonDecode(payload) as Map<String, dynamic>;

      if (message.topic == MqttTopics.status(_robotId ?? '')) {
        _lastStatus = RobotWireProtocol.decodeStatus(json, _lastStatus);
        _statusController.add(_lastStatus);
      } else if (message.topic == MqttTopics.map(_robotId ?? '')) {
        _lastMap = RobotWireProtocol.decodeMap(json, _lastMap);
        _mapController.add(_lastMap);
      } else if (message.topic == MqttTopics.events(_robotId ?? '')) {
        _eventController.add(RobotWireProtocol.decodeEvent(json));
      }
    }
  }

  @override
  Future<void> disconnect() async {
    await _updatesSub?.cancel();
    _client?.disconnect();
    _client = null;
  }

  @override
  Future<void> write(List<int> bytes) async {
    if (_client == null || _robotId == null) return;
    final MqttClientPayloadBuilder builder = MqttClientPayloadBuilder()..addUTF8String(utf8.decode(bytes));
    _client!.publishMessage(MqttTopics.commands(_robotId!), MqttQos.atLeastOnce, builder.payload!);
  }

  @override
  Future<List<int>> read() async => const [];

  @override
  Stream<List<int>> subscribe(String channel) => const Stream<List<int>>.empty();

  @override
  Future<void> sendCommand(RobotCommand command) async {
    final Map<String, dynamic> payload = RobotWireProtocol.encodeCommand(command);
    await write(utf8.encode(jsonEncode(payload)));
  }

  @override
  Stream<RobotStatus> receiveStatus() async* {
    yield _lastStatus;
    yield* _statusController.stream;
  }

  @override
  Stream<CleaningMap> receiveMap() async* {
    yield _lastMap;
    yield* _mapController.stream;
  }

  @override
  Stream<RobotEvent> receiveEvents() => _eventController.stream;

  @override
  Future<void> dispose() async {
    await _updatesSub?.cancel();
    await disconnect();
    await _statusController.close();
    await _mapController.close();
    await _eventController.close();
  }
}

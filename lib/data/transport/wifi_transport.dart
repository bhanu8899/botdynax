import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../core/constants/backend_config.dart';
import '../../domain/entities/map_data.dart';
import '../../domain/entities/robot_command.dart';
import '../../domain/entities/robot_status.dart';
import '../../domain/transport/robot_transport.dart';
import 'robot_wire_protocol.dart';

/// WiFi/cloud transport: REST for command + discovery, a persistent
/// WebSocket for live status/map/event streaming. Used once a robot has
/// been provisioned onto the home network (see BLE onboarding flow).
class WifiTransport implements RobotTransport {
  WifiTransport({Dio? dio}) : _dio = dio ?? Dio(BaseOptions(baseUrl: BackendConfig.apiBaseUrl));

  final Dio _dio;
  WebSocketChannel? _channel;
  String? _robotId;

  String? _accessToken;

  /// Set after login; sent as a query parameter on the WebSocket handshake
  /// (browsers/web_socket_channel can't set custom headers on the upgrade
  /// request) and as a Bearer header on REST calls.
  set accessToken(String? token) {
    _accessToken = token;
    _dio.options.headers['Authorization'] = token != null ? 'Bearer $token' : null;
  }

  String? get accessToken => _accessToken;

  RobotStatus _lastStatus = RobotStatus.initial('unknown', 'BotDyNax Robot');
  CleaningMap _lastMap = CleaningMap.empty('unknown');

  final StreamController<RobotStatus> _statusController = StreamController<RobotStatus>.broadcast();
  final StreamController<CleaningMap> _mapController = StreamController<CleaningMap>.broadcast();
  final StreamController<RobotEvent> _eventController = StreamController<RobotEvent>.broadcast();

  @override
  bool get isConnected => _channel != null;

  @override
  Stream<DiscoveredRobot> scan({Duration timeout = const Duration(seconds: 10)}) async* {
    final Response<List<dynamic>> response = await _dio.get<List<dynamic>>('/robots/nearby');
    for (final dynamic entry in response.data ?? const []) {
      final Map<String, dynamic> json = entry as Map<String, dynamic>;
      yield DiscoveredRobot(
        id: json['id'] as String,
        name: json['name'] as String,
        signalStrength: json['rssi'] as int? ?? 0,
        model: json['model'] as String? ?? 'BotDyNax Vacuum',
      );
    }
  }

  @override
  Future<void> connect(String robotId) async {
    _robotId = robotId;
    final Uri uri = Uri.parse(BackendConfig.robotsWebSocketUrl).replace(
      queryParameters: {
        'robotId': robotId,
        if (accessToken != null) 'token': accessToken!,
      },
    );
    _channel = WebSocketChannel.connect(uri);
    _channel!.stream.listen(
      _handleSocketFrame,
      onDone: () => _channel = null,
      onError: (Object _, StackTrace _) => _channel = null,
    );
  }

  void _handleSocketFrame(dynamic frame) {
    final Map<String, dynamic> json = jsonDecode(frame as String) as Map<String, dynamic>;
    switch (json['type']) {
      case 'status':
        _lastStatus = RobotWireProtocol.decodeStatus(json['payload'] as Map<String, dynamic>, _lastStatus);
        _statusController.add(_lastStatus);
      case 'map':
        _lastMap = RobotWireProtocol.decodeMap(json['payload'] as Map<String, dynamic>, _lastMap);
        _mapController.add(_lastMap);
      case 'event':
        _eventController.add(RobotWireProtocol.decodeEvent(json['payload'] as Map<String, dynamic>));
    }
  }

  @override
  Future<void> disconnect() async {
    await _channel?.sink.close();
    _channel = null;
  }

  @override
  Future<void> write(List<int> bytes) async {
    _channel?.sink.add(utf8.decode(bytes));
  }

  @override
  Future<List<int>> read() async => const [];

  @override
  Stream<List<int>> subscribe(String channel) => const Stream<List<int>>.empty();

  @override
  Future<void> sendCommand(RobotCommand command) async {
    final Map<String, dynamic> payload = RobotWireProtocol.encodeCommand(command);
    await _dio.post<void>('/robots/$_robotId/commands', data: payload);
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
    await disconnect();
    await _statusController.close();
    await _mapController.close();
    await _eventController.close();
  }
}

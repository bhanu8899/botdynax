import 'dart:async';

import 'package:dio/dio.dart';

import '../../domain/entities/map_data.dart';
import '../../domain/entities/robot_command.dart';
import '../../domain/entities/robot_enums.dart';
import '../../domain/entities/robot_status.dart';
import '../../domain/transport/robot_transport.dart';
import 'tuya_wire_protocol.dart';

/// Tuya Cloud transport: used for BotDyNax devices built on Tuya-certified
/// hardware modules (e.g. the Milagrow iMap Max W300, OEM'd via Tuya's
/// Smart Life ecosystem). Every call here goes through the BotDyNax
/// backend's `/tuya/robots/:robotId/*` proxy (see `backend/src/tuya`) —
/// this class never holds a Tuya Client Secret or talks to Tuya's servers
/// directly, since Tuya's HMAC signing requires a secret that must stay
/// server-side. The backend resolves `robotId` to the underlying Tuya
/// device id itself (and enforces that the caller owns that robot) — this
/// class never sees or needs the raw Tuya device id.
///
/// Tuya's Cloud API doesn't push live updates over a socket the way MQTT
/// does, so live status is achieved by polling `GET /status` on an
/// interval. [receiveMap] is a documented no-op: SLAM map data is not part
/// of this device's DP schema.
class TuyaTransport implements RobotTransport {
  TuyaTransport({required this._dio});

  final Dio _dio;
  String? _robotId;
  Timer? _pollTimer;

  RobotStatus _lastStatus = RobotStatus.initial('unknown', 'BotDyNax Robot (Tuya)');
  final CleaningMap _lastMap = CleaningMap.empty('unknown');

  final StreamController<RobotStatus> _statusController = StreamController<RobotStatus>.broadcast();
  final StreamController<RobotEvent> _eventController = StreamController<RobotEvent>.broadcast();

  static const Duration _pollInterval = Duration(seconds: 3);

  @override
  bool get isConnected => _robotId != null;

  @override
  Stream<DiscoveredRobot> scan({Duration timeout = const Duration(seconds: 10)}) async* {
    final Response<List<dynamic>> response = await _dio.get<List<dynamic>>('/tuya/devices');
    for (final dynamic entry in response.data ?? const []) {
      final Map<String, dynamic> json = entry as Map<String, dynamic>;
      yield DiscoveredRobot(
        id: json['id'] as String,
        name: json['name'] as String,
        signalStrength: json['online'] as bool? ?? false ? -50 : -100,
        model: json['productName'] as String? ?? 'Tuya Robot Vacuum',
      );
    }
  }

  @override
  Future<void> connect(String robotId) async {
    _robotId = robotId;
    // [robotId] here is already the backend fleet robot id (the caller
    // registers+links it before calling connect) — propagate it onto the
    // status so downstream consumers (schedules/history/accessories) hang
    // off the same record rather than re-registering a stray one.
    _lastStatus = _lastStatus.copyWith(robotId: robotId);
    await _pollStatus();
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_pollInterval, (_) => unawaited(_pollStatus()));
  }

  @override
  Future<void> disconnect() async {
    _pollTimer?.cancel();
    _pollTimer = null;
    _robotId = null;
  }

  Future<void> _pollStatus() async {
    final String? robotId = _robotId;
    if (robotId == null) return;

    try {
      final Response<List<dynamic>> response =
          await _dio.get<List<dynamic>>('/tuya/robots/$robotId/status');
      final List<Map<String, dynamic>> points =
          (response.data ?? const []).cast<Map<String, dynamic>>();

      final bool hadFault = _lastStatus.hasErrors;
      _lastStatus = TuyaWireProtocol.decodeStatus(points, _lastStatus);
      _statusController.add(_lastStatus);

      if (!hadFault && _lastStatus.hasErrors) {
        _eventController.add(const RobotErrorEvent(RobotErrorCode.unknown));
      }
    } on DioException {
      _lastStatus = _lastStatus.copyWith(connection: RobotConnectionState.reconnecting);
      _statusController.add(_lastStatus);
    }
  }

  @override
  Future<void> write(List<int> bytes) async {}

  @override
  Future<List<int>> read() async => const [];

  @override
  Stream<List<int>> subscribe(String channel) => const Stream<List<int>>.empty();

  @override
  Future<void> sendCommand(RobotCommand command) async {
    final String? robotId = _robotId;
    if (robotId == null) return;

    // Batches are sent as separate, sequentially-awaited POSTs (not merged
    // into one call) — see [TuyaWireProtocol.encodeCommand] for why.
    for (final List<TuyaCommand> batch in TuyaWireProtocol.encodeCommand(command)) {
      if (batch.isEmpty) continue;
      await _dio.post<void>(
        '/tuya/robots/$robotId/commands',
        data: {
          'commands': [for (final TuyaCommand c in batch) {'code': c.code, 'value': c.value}],
        },
      );
    }
  }

  @override
  Stream<RobotStatus> receiveStatus() async* {
    yield _lastStatus;
    yield* _statusController.stream;
  }

  @override
  Stream<CleaningMap> receiveMap() async* {
    // Tuya's standard Cloud API doesn't expose SLAM map data for the
    // sweeper category — yield the empty placeholder once and stop.
    yield _lastMap;
  }

  @override
  Stream<RobotEvent> receiveEvents() => _eventController.stream;

  @override
  Future<void> dispose() async {
    _pollTimer?.cancel();
    await _statusController.close();
    await _eventController.close();
  }
}

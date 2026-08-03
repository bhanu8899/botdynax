import 'dart:async';
import 'dart:convert';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../../domain/entities/map_data.dart';
import '../../domain/entities/robot_command.dart';
import '../../domain/entities/robot_status.dart';
import '../../domain/transport/robot_transport.dart';
import 'robot_wire_protocol.dart';

/// GATT UUIDs for the BotDyNax firmware BLE profile.
///
/// *** REPLACE THESE WITH YOUR REAL FIRMWARE UUIDs ***
/// Everything else in this class (scanning, connect lifecycle, notify
/// plumbing, JSON encode/decode via [RobotWireProtocol]) is complete and
/// does not need to change when you swap in real hardware.
abstract final class BleUuids {
  static final Guid service = Guid('0000fee0-0000-1000-8000-00805f9b34fb');
  static final Guid commandCharacteristic = Guid('0000fee1-0000-1000-8000-00805f9b34fb');
  static final Guid statusCharacteristic = Guid('0000fee2-0000-1000-8000-00805f9b34fb');
  static final Guid mapCharacteristic = Guid('0000fee3-0000-1000-8000-00805f9b34fb');
  static final Guid eventCharacteristic = Guid('0000fee4-0000-1000-8000-00805f9b34fb');
}

/// Bluetooth Low Energy transport: used for first-time setup and as a
/// local fallback when WiFi/MQTT are unavailable.
class BLETransport implements RobotTransport {
  BluetoothDevice? _device;
  BluetoothCharacteristic? _commandChar;
  BluetoothCharacteristic? _statusChar;
  BluetoothCharacteristic? _mapChar;
  BluetoothCharacteristic? _eventChar;

  RobotStatus _lastStatus = RobotStatus.initial('unknown', 'BotDyNax Robot');
  CleaningMap _lastMap = CleaningMap.empty('unknown');

  StreamSubscription<BluetoothConnectionState>? _connectionSub;

  @override
  bool get isConnected => _device != null;

  @override
  Stream<DiscoveredRobot> scan({Duration timeout = const Duration(seconds: 10)}) async* {
    await FlutterBluePlus.startScan(
      withServices: [BleUuids.service],
      timeout: timeout,
    );

    await for (final List<ScanResult> results in FlutterBluePlus.scanResults) {
      for (final ScanResult result in results) {
        yield DiscoveredRobot(
          id: result.device.remoteId.str,
          name: result.advertisementData.advName.isNotEmpty
              ? result.advertisementData.advName
              : 'BotDyNax Robot',
          signalStrength: result.rssi,
          model: 'BotDyNax Vacuum',
        );
      }
    }
  }

  @override
  Future<void> connect(String robotId) async {
    await FlutterBluePlus.stopScan();
    final BluetoothDevice device = BluetoothDevice(remoteId: DeviceIdentifier(robotId));
    await device.connect(license: License.nonprofit);
    _device = device;

    await _connectionSub?.cancel();
    _connectionSub = device.connectionState.listen((BluetoothConnectionState state) {
      if (state == BluetoothConnectionState.disconnected) {
        _device = null;
      }
    });

    final List<BluetoothService> services = await device.discoverServices();
    final BluetoothService botService = services.firstWhere(
      (BluetoothService s) => s.uuid == BleUuids.service,
      orElse: () => throw StateError('BotDyNax GATT service not found on $robotId'),
    );

    _commandChar = _findCharacteristic(botService, BleUuids.commandCharacteristic);
    _statusChar = _findCharacteristic(botService, BleUuids.statusCharacteristic);
    _mapChar = _findCharacteristic(botService, BleUuids.mapCharacteristic);
    _eventChar = _findCharacteristic(botService, BleUuids.eventCharacteristic);

    await _statusChar?.setNotifyValue(true);
    await _mapChar?.setNotifyValue(true);
    await _eventChar?.setNotifyValue(true);
  }

  BluetoothCharacteristic _findCharacteristic(BluetoothService service, Guid uuid) {
    return service.characteristics.firstWhere(
      (BluetoothCharacteristic c) => c.uuid == uuid,
      orElse: () => throw StateError('Characteristic $uuid not found'),
    );
  }

  @override
  Future<void> disconnect() async {
    await _connectionSub?.cancel();
    await _device?.disconnect();
    _device = null;
  }

  @override
  Future<void> write(List<int> bytes) async {
    await _commandChar?.write(bytes);
  }

  @override
  Future<List<int>> read() async {
    return _statusChar?.read() ?? const [];
  }

  @override
  Stream<List<int>> subscribe(String channel) {
    final BluetoothCharacteristic? char = switch (channel) {
      'status' => _statusChar,
      'map' => _mapChar,
      'events' => _eventChar,
      _ => null,
    };
    return char?.lastValueStream ?? const Stream<List<int>>.empty();
  }

  @override
  Future<void> sendCommand(RobotCommand command) async {
    final Map<String, dynamic> payload = RobotWireProtocol.encodeCommand(command);
    await write(utf8.encode(jsonEncode(payload)));
  }

  @override
  Stream<RobotStatus> receiveStatus() async* {
    yield _lastStatus;
    await for (final List<int> bytes in subscribe('status')) {
      if (bytes.isEmpty) continue;
      final Map<String, dynamic> json = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      _lastStatus = RobotWireProtocol.decodeStatus(json, _lastStatus);
      yield _lastStatus;
    }
  }

  @override
  Stream<CleaningMap> receiveMap() async* {
    yield _lastMap;
    await for (final List<int> bytes in subscribe('map')) {
      if (bytes.isEmpty) continue;
      final Map<String, dynamic> json = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      _lastMap = RobotWireProtocol.decodeMap(json, _lastMap);
      yield _lastMap;
    }
  }

  @override
  Stream<RobotEvent> receiveEvents() async* {
    await for (final List<int> bytes in subscribe('events')) {
      if (bytes.isEmpty) continue;
      final Map<String, dynamic> json = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      yield RobotWireProtocol.decodeEvent(json);
    }
  }

  @override
  Future<void> dispose() async {
    await _connectionSub?.cancel();
    await disconnect();
  }
}

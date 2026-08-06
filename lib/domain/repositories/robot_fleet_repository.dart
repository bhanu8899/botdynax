/// Syncs the transport-connected robot (BLE/WiFi/MQTT/Tuya/Simulator) with
/// the backend's persisted fleet record, so cloud-side features (schedules,
/// history, accessories) have a stable server-side robot id to hang data
/// off of — independent of whatever id the transport layer uses locally.
abstract class RobotFleetRepository {
  /// Registers the robot with the backend if it isn't already (matched by
  /// serial number), returning the backend's robot id either way.
  Future<String> ensureRegistered({
    required String serialNumber,
    required String name,
    required String model,
  });

  /// Ties a backend robot record to a real Tuya device id, so `/tuya/*`
  /// calls can resolve+authorize it. Safe to call repeatedly with the same
  /// device id.
  Future<void> linkTuyaDevice({required String robotId, required String tuyaDeviceId});

  /// Looks up the product's CURRENT Tuya device id server-side (no
  /// per-user OAuth needed) and links it — for devices that can get a new
  /// device id from Tuya on re-provisioning, calling this instead of
  /// [linkTuyaDevice] with a hardcoded id keeps working across that
  /// without needing an app update every time it happens.
  Future<void> linkTuyaDeviceAuto({required String robotId, required String productId});
}

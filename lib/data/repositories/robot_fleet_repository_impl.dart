import 'package:dio/dio.dart';

import '../../domain/repositories/robot_fleet_repository.dart';

class RobotFleetRepositoryImpl implements RobotFleetRepository {
  RobotFleetRepositoryImpl({required this._dio});

  final Dio _dio;

  @override
  Future<String> ensureRegistered({
    required String serialNumber,
    required String name,
    required String model,
  }) async {
    final Response<Map<String, dynamic>> response = await _dio.post<Map<String, dynamic>>(
      '/robots',
      data: {'serialNumber': serialNumber, 'name': name, 'model': model},
    );
    return response.data!['id'] as String;
  }

  @override
  Future<void> linkTuyaDevice({required String robotId, required String tuyaDeviceId}) async {
    await _dio.post<void>('/robots/$robotId/tuya-link', data: {'tuyaDeviceId': tuyaDeviceId});
  }
}

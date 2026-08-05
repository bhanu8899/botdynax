import 'package:dio/dio.dart';

import '../../domain/entities/app_notification.dart';
import '../../domain/repositories/notification_repository.dart';

const Map<String, NotificationType> _backendTypeMap = {
  'CLEANING_STARTED': NotificationType.cleaningStarted,
  'CLEANING_COMPLETED': NotificationType.cleaningCompleted,
  'LOW_BATTERY': NotificationType.lowBattery,
  'BRUSH_REPLACEMENT': NotificationType.brushReplacement,
  'FILTER_REPLACEMENT': NotificationType.filterReplacement,
  'WATER_EMPTY': NotificationType.waterEmpty,
  'DUST_BIN_FULL': NotificationType.dustBinFull,
  'ROBOT_OFFLINE': NotificationType.robotOffline,
  'FIRMWARE_AVAILABLE': NotificationType.firmwareAvailable,
};

const Map<NotificationType, String> _appToBackendType = {
  NotificationType.cleaningStarted: 'CLEANING_STARTED',
  NotificationType.cleaningCompleted: 'CLEANING_COMPLETED',
  NotificationType.lowBattery: 'LOW_BATTERY',
  NotificationType.brushReplacement: 'BRUSH_REPLACEMENT',
  NotificationType.filterReplacement: 'FILTER_REPLACEMENT',
  NotificationType.waterEmpty: 'WATER_EMPTY',
  NotificationType.dustBinFull: 'DUST_BIN_FULL',
  NotificationType.robotOffline: 'ROBOT_OFFLINE',
  NotificationType.firmwareAvailable: 'FIRMWARE_AVAILABLE',
};

class NotificationRepositoryImpl implements NotificationRepository {
  NotificationRepositoryImpl({required this._dio});

  final Dio _dio;

  @override
  Future<List<AppNotification>> findAll() async {
    final Response<List<dynamic>> response = await _dio.get<List<dynamic>>('/notifications');
    return (response.data ?? const [])
        .map((dynamic json) => _fromJson(json as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> create({required NotificationType type, required String message, String? robotId}) async {
    await _dio.post<void>(
      '/notifications',
      data: {'type': _appToBackendType[type], 'message': message, if (robotId != null) 'robotId': robotId},
    );
  }

  @override
  Future<void> markRead(String id) async {
    await _dio.patch<void>('/notifications/$id/read');
  }

  AppNotification _fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as String,
      type: _backendTypeMap[json['type'] as String] ?? NotificationType.robotOffline,
      message: json['message'] as String,
      read: json['read'] as bool,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

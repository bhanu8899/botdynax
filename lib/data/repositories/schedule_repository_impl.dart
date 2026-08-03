import 'dart:convert';

import 'package:dio/dio.dart';

import '../../domain/entities/cleaning_schedule.dart';
import '../../domain/entities/robot_enums.dart';
import '../../domain/repositories/schedule_repository.dart';

class ScheduleRepositoryImpl implements ScheduleRepository {
  ScheduleRepositoryImpl({required this._dio});

  final Dio _dio;

  @override
  Future<List<CleaningSchedule>> findAll(String robotId) async {
    final Response<List<dynamic>> response =
        await _dio.get<List<dynamic>>('/robots/$robotId/schedules');
    return (response.data ?? const [])
        .map((dynamic json) => _fromJson(json as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<CleaningSchedule> create(String robotId, CleaningSchedule schedule) async {
    final Response<Map<String, dynamic>> response = await _dio.post<Map<String, dynamic>>(
      '/robots/$robotId/schedules',
      data: _toJson(schedule),
    );
    return _fromJson(response.data!);
  }

  @override
  Future<CleaningSchedule> update(String robotId, CleaningSchedule schedule) async {
    final Response<Map<String, dynamic>> response = await _dio.patch<Map<String, dynamic>>(
      '/robots/$robotId/schedules/${schedule.id}',
      data: _toJson(schedule),
    );
    return _fromJson(response.data!);
  }

  @override
  Future<void> remove(String robotId, String scheduleId) async {
    await _dio.delete<void>('/robots/$robotId/schedules/$scheduleId');
  }

  Map<String, dynamic> _toJson(CleaningSchedule schedule) {
    return {
      'label': schedule.label,
      'daysOfWeek': schedule.daysOfWeek,
      'time': schedule.time,
      'mode': schedule.mode.name,
      'roomIds': schedule.roomIds,
      'vacuumPower': schedule.vacuumPower.name,
      'waterLevel': schedule.waterLevel.name,
      'enabled': schedule.enabled,
      'notify': schedule.notify,
    };
  }

  CleaningSchedule _fromJson(Map<String, dynamic> json) {
    final dynamic rawRoomIds = json['roomIds'];
    final List<String> roomIds = rawRoomIds is String
        ? (jsonDecode(rawRoomIds) as List<dynamic>).cast<String>()
        : (rawRoomIds as List<dynamic>).cast<String>();

    return CleaningSchedule(
      id: json['id'] as String,
      label: json['label'] as String,
      daysOfWeek: json['daysOfWeek'] as String,
      time: json['time'] as String,
      mode: CleaningMode.values.byName(json['mode'] as String),
      roomIds: roomIds,
      vacuumPower: VacuumPower.values.byName(json['vacuumPower'] as String),
      waterLevel: WaterFlow.values.byName(json['waterLevel'] as String),
      enabled: json['enabled'] as bool,
      notify: json['notify'] as bool,
    );
  }
}

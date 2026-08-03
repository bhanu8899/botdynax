import 'dart:convert';

import 'package:dio/dio.dart';

import '../../domain/entities/cleaning_session.dart';
import '../../domain/repositories/history_repository.dart';

class HistoryRepositoryImpl implements HistoryRepository {
  HistoryRepositoryImpl({required this._dio});

  final Dio _dio;

  @override
  Future<List<CleaningSession>> findAll(String robotId) async {
    final Response<List<dynamic>> response = await _dio.get<List<dynamic>>('/robots/$robotId/history');
    return (response.data ?? const [])
        .map((dynamic json) => _fromJson(json as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<CleaningSession> record({
    required String robotId,
    required double areaCleanedSqm,
    required int durationSeconds,
    required double batteryUsedPercent,
    List<String> errors = const [],
    int? cleaningScore,
  }) async {
    final Response<Map<String, dynamic>> response = await _dio.post<Map<String, dynamic>>(
      '/robots/$robotId/history',
      data: {
        'areaCleanedSqm': areaCleanedSqm,
        'durationSeconds': durationSeconds,
        'batteryUsedPercent': batteryUsedPercent,
        'errors': errors,
        if (cleaningScore != null) 'cleaningScore': cleaningScore,
      },
    );
    return _fromJson(response.data!);
  }

  CleaningSession _fromJson(Map<String, dynamic> json) {
    final dynamic rawErrors = json['errors'];
    final List<String> errors = rawErrors is String
        ? (jsonDecode(rawErrors) as List<dynamic>).cast<String>()
        : (rawErrors as List<dynamic>? ?? const []).cast<String>();

    return CleaningSession(
      id: json['id'] as String,
      startedAt: DateTime.parse(json['startedAt'] as String),
      completedAt: json['completedAt'] != null ? DateTime.parse(json['completedAt'] as String) : null,
      areaCleanedSqm: (json['areaCleanedSqm'] as num).toDouble(),
      durationSeconds: json['durationSeconds'] as int,
      batteryUsedPercent: (json['batteryUsedPercent'] as num).toDouble(),
      errors: errors,
      mapSnapshotUrl: json['mapSnapshotUrl'] as String?,
      cleaningScore: json['cleaningScore'] as int?,
    );
  }
}

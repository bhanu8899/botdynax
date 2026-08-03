import '../entities/cleaning_session.dart';

abstract class HistoryRepository {
  Future<List<CleaningSession>> findAll(String robotId);

  Future<CleaningSession> record({
    required String robotId,
    required double areaCleanedSqm,
    required int durationSeconds,
    required double batteryUsedPercent,
    List<String> errors,
    int? cleaningScore,
  });
}

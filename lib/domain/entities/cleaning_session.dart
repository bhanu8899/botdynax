import 'package:equatable/equatable.dart';

/// A completed (or in-progress) cleaning run, as recorded in cleaning
/// history.
class CleaningSession extends Equatable {
  const CleaningSession({
    required this.id,
    required this.startedAt,
    required this.completedAt,
    required this.areaCleanedSqm,
    required this.durationSeconds,
    required this.batteryUsedPercent,
    required this.errors,
    required this.mapSnapshotUrl,
    required this.cleaningScore,
  });

  final String id;
  final DateTime startedAt;
  final DateTime? completedAt;
  final double areaCleanedSqm;
  final int durationSeconds;
  final double batteryUsedPercent;
  final List<String> errors;
  final String? mapSnapshotUrl;
  final int? cleaningScore;

  Duration get duration => Duration(seconds: durationSeconds);

  @override
  List<Object?> get props => [
        id,
        startedAt,
        completedAt,
        areaCleanedSqm,
        durationSeconds,
        batteryUsedPercent,
        errors,
        mapSnapshotUrl,
        cleaningScore,
      ];
}

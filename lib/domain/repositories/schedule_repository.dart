import '../entities/cleaning_schedule.dart';
import '../entities/robot_enums.dart';

abstract class ScheduleRepository {
  Future<List<CleaningSchedule>> findAll(String robotId);

  Future<CleaningSchedule> create(String robotId, CleaningSchedule schedule);

  Future<CleaningSchedule> update(String robotId, CleaningSchedule schedule);

  Future<void> remove(String robotId, String scheduleId);
}

/// Builds a sensible new schedule to seed the create-schedule form with.
CleaningSchedule defaultNewSchedule() {
  return const CleaningSchedule(
    id: '',
    label: 'Daily Clean',
    daysOfWeek: 'DAILY',
    time: '09:00',
    mode: CleaningMode.auto,
    roomIds: [],
    vacuumPower: VacuumPower.standard,
    waterLevel: WaterFlow.medium,
    enabled: true,
    notify: true,
  );
}

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/accessory_repository_impl.dart';
import '../../data/repositories/history_repository_impl.dart';
import '../../data/repositories/notification_repository_impl.dart';
import '../../data/repositories/schedule_repository_impl.dart';
import '../../domain/entities/app_notification.dart';
import '../../domain/entities/cleaning_schedule.dart';
import '../../domain/entities/cleaning_session.dart';
import '../../domain/entities/robot_status.dart';
import '../../domain/repositories/accessory_repository.dart';
import '../../domain/repositories/history_repository.dart';
import '../../domain/repositories/notification_repository.dart';
import '../../domain/repositories/schedule_repository.dart';
import 'auth_providers.dart';
import 'robot_providers.dart';

final Provider<ScheduleRepository> scheduleRepositoryProvider = Provider<ScheduleRepository>((Ref ref) {
  return ScheduleRepositoryImpl(dio: ref.watch(apiClientProvider).dio);
});

final Provider<HistoryRepository> historyRepositoryProvider = Provider<HistoryRepository>((Ref ref) {
  return HistoryRepositoryImpl(dio: ref.watch(apiClientProvider).dio);
});

final Provider<AccessoryRepository> accessoryRepositoryProvider = Provider<AccessoryRepository>((Ref ref) {
  return AccessoryRepositoryImpl(dio: ref.watch(apiClientProvider).dio);
});

final Provider<NotificationRepository> notificationRepositoryProvider =
    Provider<NotificationRepository>((Ref ref) {
  return NotificationRepositoryImpl(dio: ref.watch(apiClientProvider).dio);
});

/// The backend's persisted robot id for the currently transport-connected
/// robot. [TuyaTransport.connect] is called with the backend robot id
/// already (see [RobotController.pairDefaultRobot]), and propagates it onto
/// [RobotStatus.robotId] — so this just re-exposes that rather than
/// re-registering, keeping schedules/history/accessories on the exact same
/// record that was linked to the real Tuya device.
final FutureProvider<String?> backendRobotIdProvider = FutureProvider<String?>((Ref ref) async {
  return ref.watch(robotStatusProvider.select((AsyncValue<RobotStatus> s) => s.valueOrNull?.robotId));
});

final FutureProviderFamily<List<CleaningSchedule>, String> schedulesProvider =
    FutureProvider.family<List<CleaningSchedule>, String>((Ref ref, String robotId) {
  return ref.watch(scheduleRepositoryProvider).findAll(robotId);
});

final FutureProviderFamily<List<CleaningSession>, String> cleaningHistoryProvider =
    FutureProvider.family<List<CleaningSession>, String>((Ref ref, String robotId) {
  return ref.watch(historyRepositoryProvider).findAll(robotId);
});

final FutureProvider<List<AppNotification>> notificationsProvider =
    FutureProvider<List<AppNotification>>((Ref ref) {
  return ref.watch(notificationRepositoryProvider).findAll();
});

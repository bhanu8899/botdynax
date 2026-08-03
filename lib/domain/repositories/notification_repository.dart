import '../entities/app_notification.dart';

abstract class NotificationRepository {
  Future<List<AppNotification>> findAll();

  Future<void> markRead(String id);
}

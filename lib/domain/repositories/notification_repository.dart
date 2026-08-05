import '../entities/app_notification.dart';

abstract class NotificationRepository {
  Future<List<AppNotification>> findAll();

  Future<void> create({required NotificationType type, required String message, String? robotId});

  Future<void> markRead(String id);
}

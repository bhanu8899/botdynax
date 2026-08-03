import 'package:equatable/equatable.dart';

enum NotificationType {
  cleaningStarted,
  cleaningCompleted,
  lowBattery,
  brushReplacement,
  filterReplacement,
  waterEmpty,
  dustBinFull,
  robotOffline,
  firmwareAvailable,
}

extension NotificationTypeMeta on NotificationType {
  String get label => switch (this) {
        NotificationType.cleaningStarted => 'Cleaning Started',
        NotificationType.cleaningCompleted => 'Cleaning Completed',
        NotificationType.lowBattery => 'Low Battery',
        NotificationType.brushReplacement => 'Brush Replacement',
        NotificationType.filterReplacement => 'Filter Replacement',
        NotificationType.waterEmpty => 'Water Empty',
        NotificationType.dustBinFull => 'Dust Bin Full',
        NotificationType.robotOffline => 'Robot Offline',
        NotificationType.firmwareAvailable => 'Firmware Available',
      };
}

class AppNotification extends Equatable {
  const AppNotification({
    required this.id,
    required this.type,
    required this.message,
    required this.read,
    required this.createdAt,
  });

  final String id;
  final NotificationType type;
  final String message;
  final bool read;
  final DateTime createdAt;

  AppNotification copyWith({bool? read}) {
    return AppNotification(
      id: id,
      type: type,
      message: message,
      read: read ?? this.read,
      createdAt: createdAt,
    );
  }

  @override
  List<Object?> get props => [id, type, message, read, createdAt];
}

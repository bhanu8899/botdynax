import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'local_notifications_service.dart';

final Provider<LocalNotificationsService> localNotificationsProvider =
    Provider<LocalNotificationsService>((Ref ref) {
  return LocalNotificationsService(FlutterLocalNotificationsPlugin());
});

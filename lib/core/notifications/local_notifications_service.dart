import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Real system notifications — the shade entry with a sound and a
/// heads-up banner — as opposed to the in-app SnackBar, which only
/// exists while the dashboard is on screen.
///
/// These are LOCAL notifications, raised by the app itself when its
/// status poll detects an event. That means they arrive whenever the app
/// is running, including in the background, but NOT when it has been
/// killed — nothing is polling then. True killed-state delivery needs a
/// server push (FCM), which is a separate piece of work.
class LocalNotificationsService {
  LocalNotificationsService(this._plugin);

  final FlutterLocalNotificationsPlugin _plugin;

  static const AndroidNotificationChannel _alertsChannel = AndroidNotificationChannel(
    'botdynax_alerts',
    'Robot alerts',
    description: 'Faults that need attention, and cleaning start/finish.',
    importance: Importance.high,
  );

  bool _ready = false;

  Future<void> init() async {
    if (_ready) return;
    const InitializationSettings settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );
    await _plugin.initialize(settings: settings);

    final AndroidFlutterLocalNotificationsPlugin? android = _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    // The channel must exist before the first notification: on Android 8+
    // its importance is what decides whether alerts make a sound and pop
    // up as a heads-up banner, and that's fixed at creation time.
    await android?.createNotificationChannel(_alertsChannel);
    await android?.requestNotificationsPermission();

    await _plugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);

    _ready = true;
  }

  /// [id] is stable per alert kind so that re-raising the same alert
  /// replaces the previous one instead of stacking duplicates in the
  /// shade every poll cycle.
  Future<void> show({required int id, required String title, required String body}) async {
    if (!_ready) return;
    try {
      await _plugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _alertsChannel.id,
            _alertsChannel.name,
            channelDescription: _alertsChannel.description,
            importance: Importance.high,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
          ),
          iOS: const DarwinNotificationDetails(presentSound: true),
        ),
      );
    } catch (error) {
      // A failed notification must never take down the status pipeline
      // that raised it.
      debugPrint('Notification failed: $error');
    }
  }

  Future<void> cancel(int id) async {
    if (!_ready) return;
    await _plugin.cancel(id: id);
  }
}

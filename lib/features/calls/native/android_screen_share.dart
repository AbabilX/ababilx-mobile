import 'dart:io' show Platform;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Keeps Android MediaProjection alive while a user shares their screen.
///
/// Android 10+ requires screen capture to run inside a foreground service.
/// Reuse the notification plugin already shipped by the app instead of adding
/// a second background-service dependency.
class AndroidScreenShare {
  AndroidScreenShare._();

  static const _notificationId = 9402;
  static final _notifications = FlutterLocalNotificationsPlugin();
  static bool _running = false;

  static Future<void> start() async {
    if (!Platform.isAndroid || _running) return;
    final android = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android == null) {
      throw StateError('Android foreground service is unavailable');
    }
    await android.startForegroundService(
      id: _notificationId,
      title: 'Sharing your screen',
      body: 'Your AbabilX call can see your screen',
      notificationDetails: const AndroidNotificationDetails(
        'screen_share',
        'Screen sharing',
        channelDescription: 'Shown while sharing your screen in a call',
        importance: Importance.low,
        priority: Priority.low,
        ongoing: true,
        autoCancel: false,
        onlyAlertOnce: true,
        icon: 'ic_stat_ababilx',
      ),
      startType: AndroidServiceStartType.startNotSticky,
      foregroundServiceTypes: const {
        AndroidServiceForegroundType.foregroundServiceTypeMediaProjection,
      },
    );
    _running = true;
  }

  static Future<void> stop() async {
    if (!Platform.isAndroid || !_running) return;
    final android = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await android?.stopForegroundService();
    _running = false;
  }
}

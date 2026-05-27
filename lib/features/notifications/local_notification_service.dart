import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../../core/constants/api_constants.dart';

/// Handles display of FCM messages when the app is in the foreground.
/// Background/terminated notifications are shown by the system automatically.
class LocalNotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();

  /// Callback to invoke on notification tap — set by the router after init.
  static void Function(String ruleId)? onNotificationTap;

  static Future<void> init() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const initSettings =
        InitializationSettings(android: androidSettings);

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        final payload = details.payload;
        if (payload != null && onNotificationTap != null) {
          onNotificationTap!(payload);
        }
      },
    );

    // Create Android notification channel
    const channel = AndroidNotificationChannel(
      NotificationChannels.standupId,
      NotificationChannels.standupName,
      description: NotificationChannels.standupDesc,
      importance: Importance.high,
      playSound: true,
      ledColor: Color(0xFF6366F1),
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  /// Show a local notification for a foreground FCM message.
  static Future<void> showFromFcm(RemoteMessage message) async {
    final ruleId = message.data['rule_id'];
    final notification = message.notification;

    await _plugin.show(
      ruleId.hashCode,
      notification?.title ?? 'AbabilX',
      notification?.body ?? 'Your standup is about to fire.',
      NotificationDetails(
        android: AndroidNotificationDetails(
          NotificationChannels.standupId,
          NotificationChannels.standupName,
          channelDescription: NotificationChannels.standupDesc,
          importance: Importance.high,
          priority: Priority.high,
          color: const Color(0xFF6366F1),
          icon: '@mipmap/ic_launcher',
        ),
      ),
      payload: ruleId, // passed to onDidReceiveNotificationResponse
    );
  }
}

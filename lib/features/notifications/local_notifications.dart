import 'dart:convert';
import 'dart:ui' show Color;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Shows local notifications while the app is in the foreground.
class LocalNotifications {
  LocalNotifications();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _ready = false;
  void Function(String payload)? onTap;

  static const _channels = <AndroidNotificationChannel>[
    AndroidNotificationChannel(
      'chat',
      'Chat',
      description: 'Direct messages and mentions',
      importance: Importance.high,
    ),
    AndroidNotificationChannel(
      'board',
      'Board',
      description: 'Task assignments, comments and board notes',
      importance: Importance.high,
    ),
    AndroidNotificationChannel(
      'wall',
      'Wall',
      description: 'Team wall mentions, comments and replies',
      importance: Importance.high,
    ),
    AndroidNotificationChannel(
      'general',
      'General',
      description: 'General AbabilX alerts',
      importance: Importance.defaultImportance,
    ),
    AndroidNotificationChannel(
      'standup_alerts',
      'Standup alerts',
      description: 'Standup pre-send reminders',
      importance: Importance.high,
    ),
    AndroidNotificationChannel(
      'team_updates',
      'Team updates',
      description: 'Team membership and activity',
      importance: Importance.defaultImportance,
    ),
    AndroidNotificationChannel(
      'ai_assistant',
      'AI assistant',
      description: 'AI assistant alerts',
      importance: Importance.defaultImportance,
    ),
  ];

  Future<void> init({required void Function(String payload) onTap}) async {
    this.onTap = onTap;
    if (_ready) return;

    // White silhouette status-bar icon (Android requires alpha-only small icon).
    const androidInit = AndroidInitializationSettings('ic_stat_ababilx');
    await _plugin.initialize(
      settings: const InitializationSettings(android: androidInit),
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload != null && payload.isNotEmpty) {
          this.onTap?.call(payload);
        }
      },
    );

    // App was terminated and opened via a local notification tap.
    try {
      final launch = await _plugin.getNotificationAppLaunchDetails();
      final payload = launch?.notificationResponse?.payload;
      if (launch?.didNotificationLaunchApp == true &&
          payload != null &&
          payload.isNotEmpty) {
        this.onTap?.call(payload);
      }
    } catch (_) {}

    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      for (final channel in _channels) {
        await android.createNotificationChannel(channel);
      }
    }

    _ready = true;
  }

  Future<bool> requestPermission() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final granted = await android?.requestNotificationsPermission();
    return granted ?? true;
  }

  Future<void> show({
    required String title,
    required String body,
    required String channelId,
    required String payload,
  }) async {
    if (!_ready) return;

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelId,
        channelDescription: 'AbabilX',
        importance: Importance.high,
        priority: Priority.high,
        // Status-bar / left badge: Android requires white-on-transparent silhouette
        // (derived from our app icon). Full-color logo goes in largeIcon below.
        icon: 'ic_stat_ababilx',
        color: const Color(0xFF6366F1),
        // Same full-color app icon as the launcher (home screen).
        largeIcon: const DrawableResourceAndroidBitmap('ic_launcher'),
      ),
    );

    await _plugin.show(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: title,
      body: body,
      notificationDetails: details,
      payload: payload,
    );
  }

  /// Encodes a navigation path (and optional data) as notification payload.
  static String encodePayload(String path, [Map<String, dynamic>? data]) {
    return jsonEncode({'path': path, 'data': data ?? {}});
  }

  static String? decodePath(String payload) {
    try {
      final map = jsonDecode(payload) as Map<String, dynamic>;
      return map['path'] as String?;
    } catch (_) {
      return payload.startsWith('/') ? payload : null;
    }
  }
}

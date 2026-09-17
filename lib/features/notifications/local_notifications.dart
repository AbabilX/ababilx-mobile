import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:ui' show Color;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'chat/chat_notification_actions.dart';
import 'notification_channels.dart';

/// One instance per isolate: a second initialization would replace the
/// app tap callback; notification actions reuse this initialized singleton.
class LocalNotifications {
  factory LocalNotifications() => _instance;

  LocalNotifications._();

  static final LocalNotifications _instance = LocalNotifications._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _ready = false;
  void Function(String payload)? onTap;

  static const _iosDetails = DarwinNotificationDetails(
    presentAlert: true,
    presentBadge: true,
    presentSound: true,
  );

  Future<void> init({required void Function(String payload) onTap}) async {
    this.onTap = onTap;
    if (_ready) return;

    // White silhouette status-bar icon (Android requires alpha-only small icon).
    const androidInit = AndroidInitializationSettings('ic_stat_ababilx');
    // iOS: do not prompt here. FcmService already asks once via Firebase,
    // matching Signal's single requestAuthorization. Android ignores this.
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: androidInit,
        iOS: iosInit,
      ),
      onDidReceiveNotificationResponse: (response) async {
        // A reply or mark-read press is not a tap: it must run the action and
        // leave the user where they are, not open the conversation.
        if (await handleChatNotificationAction(response)) return;
        final payload = response.payload;
        if (payload != null && payload.isNotEmpty) {
          this.onTap?.call(payload);
        }
      },
      onDidReceiveBackgroundNotificationResponse:
          chatNotificationBackgroundAction,
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
      for (final channel in notificationChannels) {
        await android.createNotificationChannel(channel);
      }
    }

    _ready = true;
  }

  /// Initialises the plugin inside the FCM background isolate, where no tap
  /// callback can be wired: a tap there launches the app, and the main isolate
  /// picks the payload up through getNotificationAppLaunchDetails.
  Future<void> initForBackground() async {
    if (_ready) return;
    const androidInit = AndroidInitializationSettings('ic_stat_ababilx');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: androidInit,
        iOS: iosInit,
      ),
      onDidReceiveBackgroundNotificationResponse:
          chatNotificationBackgroundAction,
    );
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      for (final channel in notificationChannels) {
        await android.createNotificationChannel(channel);
      }
    }
    _ready = true;
  }

  Future<bool> requestPermission() async {
    if (Platform.isIOS) {
      final ios = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      final granted = await ios?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      // A missing plugin must not wipe a Firebase grant on iOS.
      return granted ?? true;
    }
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

    /// Stable id keeps a message from being shown twice (foreground handler and
    /// background isolate can both see the same push).
    int? id,
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
      iOS: _iosDetails,
    );

    await _plugin.show(
      id: id ?? DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: title,
      body: body,
      notificationDetails: details,
      payload: payload,
    );
  }

  /// Shows a notification built by a caller that needs full control of the
  /// Android details — chat uses it for the MessagingStyle thread and its
  /// reply buttons.
  Future<void> showDetails({
    required int id,
    required String title,
    required String body,
    required String payload,
    required AndroidNotificationDetails android,
  }) async {
    if (!_ready) return;
    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: android,
        iOS: _iosDetails,
      ),
      payload: payload,
    );
  }

  Future<void> cancel(int id) async {
    if (!_ready) return;
    try {
      await _plugin.cancel(id: id);
    } catch (_) {
      // Already gone is fine.
    }
  }

  Future<void> cancelAll({bool strict = false}) async {
    if (!_ready) return;
    try {
      await _plugin.cancelAll();
    } catch (_) {
      if (strict) rethrow;
    }
  }

  static String encodePayload(String path, [Map<String, dynamic>? data]) {
    return jsonEncode({'path': path, 'data': data ?? {}});
  }

  /// The FCM data map a payload was built from — what a notification action
  /// needs to know which conversation it is acting on.
  static Map<String, dynamic> decodeData(String payload) {
    try {
      final map = jsonDecode(payload) as Map<String, dynamic>;
      final data = map['data'];
      return data is Map ? Map<String, dynamic>.from(data) : {};
    } catch (_) {
      return {};
    }
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

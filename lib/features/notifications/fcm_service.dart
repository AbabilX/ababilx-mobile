import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/storage/secure_storage.dart';
import '../calls/native/android_call_ui.dart';
import 'data/device_repository.dart';
import 'fcm_log.dart';
import 'local_notifications.dart';
import 'notification_router.dart';

/// Owns FCM permission, token sync, and foreground display.
class FcmService {
  FcmService({
    required DeviceRepository devices,
    required SecureStorage storage,
    required LocalNotifications localNotifications,
  }) : _devices = devices,
       _storage = storage,
       _local = localNotifications;

  final DeviceRepository _devices;
  final SecureStorage _storage;
  final LocalNotifications _local;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  GoRouter? router;
  StreamSubscription<String>? _tokenRefreshSub;
  StreamSubscription<RemoteMessage>? _foregroundSub;
  StreamSubscription<RemoteMessage>? _openedSub;
  bool _started = false;

  /// Deep-link path from a notification tap; survives auth / router races.
  String? _pendingPath;

  /// Permission currently granted (Android POST_NOTIFICATIONS / FCM).
  bool permissionGranted = false;

  Future<bool> start() async {
    fcmLog(
      'start.begin',
      'api=${ApiConstants.baseUrl} alreadyStarted=$_started granted=$permissionGranted',
    );
    if (_started && permissionGranted) {
      fcmLog('start.skip', 'already running with permission');
      flushPendingNav();
      return true;
    }

    // Capture cold-start tap ASAP (before permission / token work).
    try {
      final initial = await _messaging.getInitialMessage();
      if (initial != null) {
        fcmLog(
          'initial_message',
          'type=${initial.data['type']} conversation=${initial.data['conversation_id']}',
        );
        _onOpened(initial);
      } else {
        fcmLog('initial_message', 'none');
      }
    } catch (e) {
      fcmLog('initial_message.fail', e);
    }

    try {
      await _local.init(onTap: _handlePayload);
      fcmLog('local_notif.init.ok');
    } catch (e) {
      fcmLog('local_notif.init.fail', e);
    }

    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      fcmLog(
        'permission.firebase',
        'authorizationStatus=${settings.authorizationStatus}',
      );

      final localGranted = await _local.requestPermission();
      fcmLog('permission.android', 'granted=$localGranted');

      permissionGranted =
          localGranted &&
          settings.authorizationStatus != AuthorizationStatus.denied;
      if (permissionGranted) {
        await FlutterCallkitIncoming.requestFullIntentPermission();
      }
    } catch (e) {
      fcmLog('permission.fail', e);
      permissionGranted = false;
    }

    if (!permissionGranted) {
      fcmLog('start.abort', 'permission denied — token will not register');
      flushPendingNav();
      return false;
    }

    try {
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    } catch (e) {
      fcmLog('foreground_options.fail', e);
    }

    await _syncToken();

    _tokenRefreshSub?.cancel();
    _tokenRefreshSub = _messaging.onTokenRefresh.listen((token) async {
      fcmLog('token.refresh', fcmTokenPreview(token));
      await _storage.writeFcmToken(token);
      try {
        await _devices.register(token);
        fcmLog('token.refresh.register.ok');
      } catch (e) {
        fcmLog('token.refresh.register.fail', e);
      }
    });

    _foregroundSub?.cancel();
    _foregroundSub = FirebaseMessaging.onMessage.listen(_onForeground);

    _openedSub?.cancel();
    _openedSub = FirebaseMessaging.onMessageOpenedApp.listen(_onOpened);

    _started = true;
    fcmLog('start.done', 'listeners attached');
    flushPendingNav();
    return true;
  }

  /// Called when [router] is attached or auth becomes ready.
  void flushPendingNav() {
    final path = _pendingPath;
    final r = router;
    if (path == null || path.isEmpty) return;
    if (r == null) {
      fcmLog('navigate.defer', 'router not ready path=$path');
      return;
    }
    Future<void>.delayed(const Duration(milliseconds: 350), () {
      final pending = _pendingPath;
      if (pending == null || pending.isEmpty) return;
      try {
        r.go(pending);
        _pendingPath = null;
        fcmLog('navigate.ok', pending);
      } catch (e) {
        fcmLog('navigate.fail', e);
      }
    });
  }

  /// Peek without clearing — used by GoRouter login redirect.
  String? get pendingPath => _pendingPath;

  /// Take and clear a pending deep link (e.g. cold-start after login).
  String? consumePendingPath() {
    final path = _pendingPath;
    _pendingPath = null;
    return path;
  }

  /// Re-request permission from profile and register if granted.
  Future<bool> retryPermission() async {
    fcmLog('retry_permission');
    _started = false;
    return start();
  }

  Future<void> stopAndDeregister() async {
    fcmLog('stop.begin');
    await _tokenRefreshSub?.cancel();
    await _foregroundSub?.cancel();
    await _openedSub?.cancel();
    _tokenRefreshSub = null;
    _foregroundSub = null;
    _openedSub = null;
    _started = false;

    final token = await _storage.readFcmToken() ?? await _messaging.getToken();
    if (token != null) {
      try {
        await _devices.deregister(token);
      } catch (e) {
        fcmLog('stop.deregister.fail', e);
      }
      await _storage.deleteFcmToken();
    } else {
      fcmLog('stop.no_token');
    }
    fcmLog('stop.done');
  }

  Future<void> _syncToken() async {
    fcmLog('token.sync.begin');
    String? token;
    try {
      token = await _messaging.getToken();
    } catch (e) {
      fcmLog('token.get.fail', e);
      return;
    }

    if (token == null) {
      fcmLog(
        'token.get.null',
        'Firebase returned null — check google-services / Play Services',
      );
      return;
    }

    fcmLog('token.get.ok', fcmTokenPreview(token));
    await _storage.writeFcmToken(token);

    try {
      await _devices.register(token);
      fcmLog('token.sync.done', 'registered with API');
    } catch (e) {
      fcmLog(
        'token.sync.fail',
        'API register failed — push will not arrive until this succeeds | $e',
      );
    }
  }

  Future<void> _onForeground(RemoteMessage message) async {
    final title = message.notification?.title ?? 'AbabilX';
    final body = message.notification?.body ?? '';
    final data = Map<String, dynamic>.from(message.data);
    final path = NotificationRouter.pathForData(data);
    final channel = _channelFor(data['type']?.toString());

    if (data['type'] == 'voice_call') {
      await AndroidCallUi.showIncomingFromPush(data);
      return;
    }

    fcmLog(
      'push.foreground',
      'title=$title body=$body type=${data['type']} → local channel=$channel path=$path',
    );

    try {
      await _local.show(
        title: title,
        body: body,
        channelId: channel,
        payload: LocalNotifications.encodePayload(path, data),
      );
      fcmLog('push.foreground.shown');
    } catch (e) {
      fcmLog('push.foreground.show.fail', e);
    }
  }

  void _onOpened(RemoteMessage message) {
    final data = Map<String, dynamic>.from(message.data);
    final path = NotificationRouter.pathForData(data);
    fcmLog(
      'push.opened',
      'type=${data['type']} conversation=${data['conversation_id']} '
          'message=${data['message_id']} path=$path',
    );
    _go(path);
  }

  void _handlePayload(String payload) {
    final path = LocalNotifications.decodePath(payload);
    fcmLog('push.local_tap', 'payload=$payload path=$path');
    if (path != null) _go(path);
  }

  void _go(String path) {
    _pendingPath = path;
    fcmLog('navigate.queue', path);
    flushPendingNav();
  }

  String _channelFor(String? type) {
    switch (type) {
      case 'chat_dm':
      case 'chat_mention':
      case 'chat_message':
        return 'chat';
      case 'voice_call':
        return 'voice_calls';
      case 'pre_send_review':
        return 'standup_alerts';
      case 'ai_assistant':
        return 'ai_assistant';
      case 'team_member_left':
        return 'team_updates';
      default:
        return 'general';
    }
  }

  bool get isStarted => _started;
}

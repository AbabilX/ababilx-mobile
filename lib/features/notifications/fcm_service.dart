import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/storage/secure_storage.dart';
import '../calls/call_lifecycle.dart';
import '../calls/native/android_call_ui.dart';
import '../calls/native/android_group_call_ui.dart';
import '../calls/native/background_voice_call_gate.dart';
import '../calls/native/voice_call_ended_guard.dart';
import 'chat/chat_notification_presenter.dart';
import 'chat_push_notification.dart';
import 'data/device_repository.dart';
import 'data/push_token_registration.dart';
import 'fcm_log.dart';
import 'local_notifications.dart';
import '../ghost/ghost_push.dart';
import '../messages/chat-focus/chat_focus_reporter.dart';
import 'notification_router.dart';

/// Owns FCM permission, token sync, and foreground display.
class FcmService {
  // Params keep public names (devices/storage) while fields stay private —
  // an initializing formal would force the external param name to match the
  // private field name, which callers in fcm_provider.dart can't reference.
  FcmService({
    required DeviceRepository devices,
    required SecureStorage storage,
    required LocalNotifications localNotifications,
    FirebaseMessaging? messaging,
  }) : _devices = devices, // ignore: prefer_initializing_formals
       _storage = storage, // ignore: prefer_initializing_formals
       _local = localNotifications,
       _messaging = messaging ?? FirebaseMessaging.instance;

  final DeviceRepository _devices;
  final SecureStorage _storage;
  final LocalNotifications _local;
  final FirebaseMessaging _messaging;

  GoRouter? router;
  StreamSubscription<String>? _tokenRefreshSub;
  StreamSubscription<RemoteMessage>? _foregroundSub;
  StreamSubscription<RemoteMessage>? _openedSub;
  bool _started = false;
  bool _sessionActive = false;
  int _session = 0;
  Future<bool>? _starting;
  Future<void>? _stopping;
  late final _registration = PushTokenRegistration(
    loadToken: _loadPushToken,
    saveToken: _storage.writeFcmToken,
    registerToken: (token) => _devices.register(token, platform: _pushPlatform),
    onFailure: (error) => fcmLog('token.registration.retry', error.runtimeType),
  );

  /// Recovery never reopens the permission dialog or registers after logout.
  Future<void> retryPendingRegistration() => _registration.retryPending();

  /// Deep-link path from a notification tap; survives auth / router races.
  String? _pendingPath;

  /// Permission currently granted (Android POST_NOTIFICATIONS / FCM).
  bool permissionGranted = false;

  Future<bool> start() {
    if (_stopping != null) return Future.value(false);
    if (_starting != null) return _starting!;
    _sessionActive = true;
    final session = _session;
    return _starting = _start(session).whenComplete(() {
      if (session == _session) _starting = null;
    });
  }

  bool _isCurrent(int session) => _sessionActive && session == _session;

  Future<bool> _start(int session) async {
    fcmLog(
      'start.begin',
      'api=${ApiConstants.baseUrl} alreadyStarted=$_started granted=$permissionGranted',
    );
    if (_started && permissionGranted) {
      fcmLog('start.skip', 'already running with permission');
      unawaited(retryPendingRegistration());
      flushPendingNav();
      return true;
    }

    // Capture cold-start tap ASAP (before permission / token work).
    try {
      final initial = await _messaging.getInitialMessage();
      if (!_isCurrent(session)) return false;
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

    if (!_isCurrent(session)) return false;
    try {
      await _local.init(onTap: _handlePayload);
      fcmLog('local_notif.init.ok');
    } catch (e) {
      fcmLog('local_notif.init.fail', e);
    }

    if (!_isCurrent(session)) return false;
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

      if (!_isCurrent(session)) return false;
      final localGranted = await _local.requestPermission();
      fcmLog('permission.android', 'granted=$localGranted');

      if (!_isCurrent(session)) return false;
      permissionGranted =
          localGranted &&
          settings.authorizationStatus != AuthorizationStatus.denied;
      // Android 14's full-screen-intent page is NOT opened from here: this
      // runs on every cold start, including the one a call's Accept causes,
      // and on a locked phone. `FcmBootstrap` asks via FullScreenIntentPrompt.
    } catch (e) {
      fcmLog('permission.fail', e);
      if (!_isCurrent(session)) return false;
      permissionGranted = false;
    }

    // Register before the permission gate, and whatever it decided.
    //
    // A refused (or merely dismissed) notification prompt used to abort here,
    // so the account got no `device_tokens` row at all — and nothing brings the
    // user back through `start()` when they enable notifications later from
    // system settings. The phone then received *nothing*, silently, until the
    // next cold start happened to catch the permission already granted; a new
    // account's first incoming call is exactly when that window is open. The
    // server logs the other end of it as `[fcm] no devices user=…`.
    //
    // Registering anyway is also correct on its own terms: call and encrypted
    // chat pushes are data-only, and Android delivers those to the app whether
    // or not it may draw a notification.
    if (!_isCurrent(session)) return false;
    await _tokenRefreshSub?.cancel();
    if (!_isCurrent(session)) return false;
    // Subscribe before fetching so a rotation during registration is not lost.
    // start() activates the registrar synchronously, before any event arrives.
    final registration = _registration.start();
    _tokenRefreshSub = _messaging.onTokenRefresh.listen(
      (token) {
        if (!_isCurrent(session)) return;
        unawaited(_registration.tokenChanged(token));
      },
      onError: (Object error) {
        fcmLog('token.refresh.fail', error.runtimeType);
      },
    );
    // Do not hold notification listeners hostage to a slow registration API.
    unawaited(registration);

    if (!permissionGranted) {
      fcmLog(
        'start.abort',
        'permission denied — token registration active, UI muted',
      );
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

    if (!_isCurrent(session)) return false;
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
        _openDeepLink(r, pending);
        _pendingPath = null;
        fcmLog('navigate.ok', pending);
      } catch (e) {
        fcmLog('navigate.fail', e);
      }
    });
  }

  /// Seed a shell tab under detail routes so back reaches home before exit.
  void _openDeepLink(GoRouter r, String path) {
    final bare = path.split('?').first;
    if (bare == '/messages' || bare == '/login' || _isShellTab(bare)) {
      r.go(path);
      return;
    }
    r.go(_seedTabFor(bare));
    Future<void>.delayed(const Duration(milliseconds: 50), () {
      try {
        r.push(path);
      } catch (e) {
        fcmLog('navigate.push.fail', e);
        r.go(path);
      }
    });
  }

  /// Shell tab a detail route belongs to — pushed under it so Android back
  /// lands on that tab instead of exiting the app.
  String _seedTabFor(String bare) {
    if (bare.startsWith('/board/')) return '/board';
    if (bare.startsWith('/wall/')) return '/wall';
    return '/messages';
  }

  bool _isShellTab(String path) {
    return path == '/wall' ||
        path == '/crm' ||
        path == '/crm/contacts' ||
        path == '/crm/leads' ||
        path == '/crm/followups' ||
        path == '/crm/organizations' ||
        path == '/board';
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

  Future<void> stopAndDeregister() =>
      _stopping ??= _stopAndDeregister().whenComplete(() => _stopping = null);

  Future<void> _stopAndDeregister() async {
    fcmLog('stop.begin');
    _sessionActive = false;
    _session++;
    _starting = null;
    final registrationStopped = _registration.stop();
    // A notification opened for the previous session must not navigate the
    // next account immediately after login.
    _pendingPath = null;
    await _tokenRefreshSub?.cancel();
    await _foregroundSub?.cancel();
    await _openedSub?.cancel();
    _tokenRefreshSub = null;
    _foregroundSub = null;
    _openedSub = null;
    _started = false;

    await registrationStopped;
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

  Future<String?> _loadPushToken() async {
    if (Platform.isIOS &&
        await _messaging.getAPNSToken().timeout(const Duration(seconds: 15)) ==
            null) {
      // APNs may not be ready at startup. The registrar will retry.
      return null;
    }
    return _messaging.getToken().timeout(const Duration(seconds: 15));
  }

  void dispose() {
    _sessionActive = false;
    _session++;
    unawaited(_registration.stop());
    unawaited(_tokenRefreshSub?.cancel());
    unawaited(_foregroundSub?.cancel());
    unawaited(_openedSub?.cancel());
  }

  Future<void> _onForeground(RemoteMessage message) async {
    final title = message.notification?.title ?? 'AbabilX';
    final body = message.notification?.body ?? '';
    final data = Map<String, dynamic>.from(message.data);
    final path = NotificationRouter.pathForData(data);
    final channel = _channelFor(data['type']?.toString());

    final type = data['type'];
    if (isGhostPush(data)) {
      await handleGhostPush(_local, data, appOnScreen: flutterOwnsRingingUi);
      return;
    }
    if (type == 'voice_call_ended') {
      // Silent terminal push for a call whose WS cannot reach this process.
      final callId = data['call_id']?.toString() ?? '';
      await VoiceCallEndedGuard.markEnded(callId);
      await AndroidCallUi.endCall(callId);
      return;
    }
    if (type == 'voice_call_answered' || type == 'group_call_joined') {
      // Silent control push: one of this account's devices picked up, so the
      // rest must stop ringing. Swallowed here on purpose — the call providers
      // subscribe to the same foreground stream and act on it with the live
      // call state, which is the only thing that can tell the device that
      // answered from a device that merely knows about the call. Acting on it
      // twice risks tearing down the answerer's own call.
      return;
    }
    if (type == 'group_call_ended') {
      // This is a silent lifecycle push, not a user notification. It closes a
      // native ring/ongoing surface when the WebSocket missed the ended event.
      await AndroidGroupCallUi.endCall(data['call_id']?.toString() ?? '');
      return;
    }
    if (type == 'voice_call' || type == 'group_call') {
      // While the app is on screen the socket drives the call providers and
      // they raise the Flutter ringing UI. Showing CallKit as well puts a
      // native full-screen activity over that screen and steals audio focus,
      // so the in-app ringtone goes silent behind an unexpected overlay.
      if (flutterOwnsRingingUi) {
        fcmLog('push.$type.skip', 'app on screen — in-app call UI owns this');
        return;
      }
      if (type == 'voice_call') {
        if (!await BackgroundVoiceCallGate.shouldPresent(data)) return;
        await AndroidCallUi.showIncomingFromPush(data);
      } else {
        await AndroidGroupCallUi.showIncomingFromPush(data);
      }
      return;
    }

    if (isChatPush(data)) {
      // The message is already landing in the open chat over the socket; a
      // buzz and a tray line for it would be noise. The server usually skips
      // this push itself (chat.focus), this catches the race around it.
      if (ChatScreenFocus.isOnScreen(
        data['conversation_id']?.toString() ?? '',
      )) {
        fcmLog('push.foreground.chat.skip', 'conversation on screen');
        return;
      }
      // Chat entries are drawn here even when the push carried a notification
      // block, so the message lands in the threaded MessagingStyle entry with
      // its reply button instead of a flat system tray line.
      fcmLog('push.foreground.chat', 'type=${data['type']} path=$path');
      try {
        if (isEncryptedChatPush(data)) {
          await showEncryptedChatPush(_local, data);
        } else {
          await showPlainChatPush(_local, data, body);
        }
        fcmLog('push.foreground.shown');
      } catch (e) {
        fcmLog('push.foreground.show.fail', e);
      }
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
    // Opening the conversation reads it: the stacked thread in the shade would
    // otherwise come back on the next message with messages already read.
    final data = LocalNotifications.decodeData(payload);
    if (isChatPush(data)) {
      unawaited(
        ChatNotificationPresenter.dismiss(
          _local,
          data['conversation_id']?.toString() ?? '',
        ),
      );
    }
    if (path != null) _go(path);
  }

  void _go(String path) {
    final safePath = _safeDeepLink(path);
    _pendingPath = safePath;
    fcmLog('navigate.queue', safePath);
    flushPendingNav();
  }

  /// Older already-delivered local notifications may still carry these raw
  /// routes. Providers own call navigation after live-state verification.
  String _safeDeepLink(String path) {
    final bare = path.split('?').first;
    if (bare == '/call' || bare == '/group-call') return '/messages';
    return path;
  }

  String _channelFor(String? type) {
    switch (type) {
      case 'chat_dm':
      case 'chat_mention':
      case 'chat_message':
        return 'chat';
      case 'kanban_assignment':
      case 'kanban_mention':
      case 'kanban_comment':
      case 'kanban_watcher':
      case 'board_notes':
      case 'board_notes_mention':
        return 'board';
      case 'wall_mention':
      case 'wall_comment':
      case 'wall_reply':
      case 'wall_category_request':
        return 'wall';
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

  String get _pushPlatform => Platform.isIOS ? 'ios' : 'android';

  bool get isStarted => _started;
}

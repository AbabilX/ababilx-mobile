import 'dart:io' show Platform;
import 'dart:ui' show DartPluginRegistrant;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';

import 'app.dart';
import 'firebase_options.dart';
import 'features/messages/wallpaper/chat_wallpaper_store.dart';
import 'features/calls/native/android_call_background.dart';
import 'features/calls/native/android_call_ui.dart';
import 'features/calls/native/android_group_call_ui.dart';
import 'features/calls/native/background_voice_call_gate.dart';
import 'features/calls/native/answered_elsewhere.dart';
import 'features/calls/native/call_answered_guard.dart';
import 'features/calls/native/voice_call_ended_guard.dart';
import 'features/ghost/ghost_push.dart';
import 'features/notifications/chat_push_notification.dart';
import 'features/notifications/local_notifications.dart';
import 'features/notifications/vitals/push_latency_store.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // How late this push was, recorded before anything is drawn. Only pushes
  // that wake this isolate are measured — one landing in the foreground app is
  // fast by construction and would only flatter the numbers. This is the sole
  // evidence behind the battery-optimization prompt; see
  // `vitals/slow_notification_heuristics.dart`.
  final sentTime = message.sentTime;
  if (sentTime != null) await PushLatencyStore.record(sentTime);
  final data = Map<String, dynamic>.from(message.data);
  final type = data['type'];
  if (type == 'voice_call' || type == 'group_call') {
    // This isolate is not `main()`, so the CallKit background executor has
    // never been started in this process — and the plugin only delivers a
    // call event to it when it is already running. Without this, Decline on
    // the full-screen CallKit screen (or in its notification) of a phone whose
    // app was killed went nowhere: the tone kept playing and the call was
    // never declined. Registering here starts that executor before the ringing
    // UI is raised. `CallEventBridge.kt` is the native backstop for the same
    // failure.
    try {
      await FlutterCallkitIncoming.onBackgroundMessage(
        androidCallkitBackgroundHandler,
      );
    } catch (_) {
      // Best effort — a failure here must not stop the call from ringing.
    }
  }
  switch (type) {
    case 'voice_call':
      if (!await BackgroundVoiceCallGate.shouldPresent(data)) return;
      await AndroidCallUi.showIncomingFromPush(data);
    case 'voice_call_ended':
      final callId = data['call_id']?.toString() ?? '';
      if (callId.isNotEmpty) await VoiceCallEndedGuard.markEnded(callId);
      await AndroidCallUi.endCall(callId);
    case 'voice_call_answered':
      // Another device on this account picked up. Only the ringing surface
      // goes away — this is NOT a terminal event, so the call is deliberately
      // not marked ended: that mark is what suppresses a later `incoming`, and
      // an answered call is one that very much still exists.
      final answeredId = data['call_id']?.toString() ?? '';
      if (answeredId.isEmpty) break;
      // Addressed to the account, so it reaches the answering device too.
      if (await _answeredOnAnotherDevice(answeredId)) {
        await AndroidCallUi.endCall(answeredId);
      }
    case 'group_call_joined':
      // Same shape for a channel call: this member joined on another device.
      final joinedId = data['call_id']?.toString() ?? '';
      if (joinedId.isEmpty) break;
      if (await _answeredOnAnotherDevice(joinedId)) {
        await AndroidGroupCallUi.endCall(joinedId);
      }
    case 'group_call':
      await AndroidGroupCallUi.showIncomingFromPush(data);
    case 'group_call_ended':
      await AndroidGroupCallUi.endCall(data['call_id']?.toString() ?? '');
    case 'chat_dm':
    case 'chat_message':
    case 'chat_mention':
      await _handleChatPushInBackground(data);
    case 'ghost_invite':
    case 'ghost_closed':
      try {
        final local = LocalNotifications();
        await local.initForBackground();
        await handleGhostPush(local, data, appOnScreen: false);
      } catch (_) {
        // Best effort: a background isolate must never throw.
      }
  }
}

/// A control push says one of this account's devices answered. This isolate
/// holds no call state, so the durable mark is the only way to tell whether it
/// was this device — which must keep its live call — or another one, whose
/// ringing surface here is now stale.
Future<bool> _answeredOnAnotherDevice(String callId) async =>
    decideAnsweredElsewhere(
      answeredHere: await CallAnsweredGuard.answeredHere(callId),
      ringingHere: false,
    ) ==
    AnsweredElsewhereAction.dismissNative;

/// Encrypted DMs arrive data-only on Android: the server holds no plaintext, so
/// this isolate decrypts and raises the notification itself. Everything here is
/// best-effort — an uncaught throw in the background isolate takes the process
/// down, and a missed notification must never do that.
///
/// A plaintext chat push only reaches this handler when it arrived data-only
/// too; one that carried a notification block is drawn by Android itself and
/// never wakes Dart.
Future<void> _handleChatPushInBackground(Map<String, dynamic> data) async {
  if (!isChatPush(data)) return;
  try {
    // Fresh isolate: plugins (secure storage, local notifications) are not
    // registered until asked for.
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();
    final local = LocalNotifications();
    await local.initForBackground();
    if (isEncryptedChatPush(data)) {
      await showEncryptedChatPush(local, data);
    } else {
      await showPlainChatPush(local, data, _plainPushBody(data));
    }
  } catch (_) {
    // Nothing to show is better than a crash loop on every message.
  }
}

/// Data-only pushes carry no notification block, so the preview the server
/// rendered travels in the data map.
String _plainPushBody(Map<String, dynamic> data) {
  final body = data['body']?.toString() ?? '';
  return body.isEmpty ? 'Open AbabilX to read the message' : body;
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  // Android-only plugin method; iOS has no implementation and throws.
  if (Platform.isAndroid) {
    await FlutterCallkitIncoming.onBackgroundMessage(
      androidCallkitBackgroundHandler,
    );
  }

  // Fresh installs get the theme-aware chat wallpaper; upgrades stay plain.
  // Must run before other features write SharedPreferences.
  await const ChatWallpaperStore().shipDefaultIfFreshInstall();

  runApp(const ProviderScope(child: AbabilXApp()));
}

import 'dart:ui' show DartPluginRegistrant;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';

import 'app.dart';
import 'firebase_options.dart';
import 'features/calls/native/android_call_background.dart';
import 'features/calls/native/android_call_ui.dart';
import 'features/calls/native/android_group_call_ui.dart';
import 'features/calls/native/background_voice_call_gate.dart';
import 'features/calls/native/voice_call_ended_guard.dart';
import 'features/notifications/chat_push_notification.dart';
import 'features/notifications/local_notifications.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
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
    case 'group_call':
      await AndroidGroupCallUi.showIncomingFromPush(data);
    case 'group_call_ended':
      await AndroidGroupCallUi.endCall(data['call_id']?.toString() ?? '');
    case 'chat_dm':
    case 'chat_message':
    case 'chat_mention':
      await _handleChatPushInBackground(data);
  }
}

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
  await FlutterCallkitIncoming.onBackgroundMessage(
    androidCallkitBackgroundHandler,
  );

  runApp(const ProviderScope(child: AbabilXApp()));
}

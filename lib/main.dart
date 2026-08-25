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
import 'features/calls/native/voice_call_ended_guard.dart';
import 'features/notifications/chat_push_notification.dart';
import 'features/notifications/local_notifications.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  final data = Map<String, dynamic>.from(message.data);
  switch (data['type']) {
    case 'voice_call':
      final callId = data['call_id']?.toString() ?? '';
      // The "ended" push for this same call can land first — NATS/FCM gives
      // no ordering guarantee across the two hops. Showing the full-screen
      // UI after that would leave it stuck ringing with no second "ended"
      // push ever coming to close it.
      if (callId.isNotEmpty && await VoiceCallEndedGuard.wasEnded(callId)) {
        return;
      }
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
      await _handleChatPushInBackground(data);
  }
}

/// Encrypted DMs arrive data-only on Android: the server holds no plaintext, so
/// this isolate decrypts and raises the notification itself. Everything here is
/// best-effort — an uncaught throw in the background isolate takes the process
/// down, and a missed notification must never do that.
Future<void> _handleChatPushInBackground(Map<String, dynamic> data) async {
  if (!isEncryptedChatPush(data)) return;
  try {
    // Fresh isolate: plugins (secure storage, local notifications) are not
    // registered until asked for.
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();
    final local = LocalNotifications();
    await local.initForBackground();
    await showEncryptedChatPush(local, data);
  } catch (_) {
    // Nothing to show is better than a crash loop on every message.
  }
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

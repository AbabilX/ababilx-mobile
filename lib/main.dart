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
import 'features/notifications/chat_push_notification.dart';
import 'features/notifications/local_notifications.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  final data = Map<String, dynamic>.from(message.data);
  switch (data['type']) {
    case 'voice_call':
      await AndroidCallUi.showIncomingFromPush(data);
    case 'voice_call_ended':
      await AndroidCallUi.endCall(data['call_id']?.toString() ?? '');
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

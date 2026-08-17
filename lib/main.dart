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

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  final data = Map<String, dynamic>.from(message.data);
  switch (data['type']) {
    case 'voice_call':
      await AndroidCallUi.showIncomingFromPush(data);
    case 'group_call':
      await AndroidGroupCallUi.showIncomingFromPush(data);
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

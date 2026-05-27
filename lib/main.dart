import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'features/notifications/local_notification_service.dart';

/// Background FCM handler — must be a top-level function.
/// Called when app is in background/terminated and FCM message arrives.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Firebase must be re-initialized in background isolate.
  await Firebase.initializeApp();
  // System displays the notification automatically from the FCM payload.
  // No additional action needed here.
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp();

  // Register background FCM handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Request notification permissions (Android 13+)
  await FirebaseMessaging.instance.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  // Create Android notification channel + init local notifications
  await LocalNotificationService.init();

  runApp(
    const ProviderScope(
      child: AbabilXApp(),
    ),
  );
}

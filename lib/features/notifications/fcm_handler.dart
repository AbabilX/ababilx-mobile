import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:go_router/go_router.dart';
import 'local_notification_service.dart';

/// Wires up all FCM message listeners.
/// Must be called after Firebase.initializeApp() and GoRouter is created.
class FcmHandler {
  FcmHandler._();

  static void init(GoRouter router) {
    // Tap handler from local notification service (foreground messages)
    LocalNotificationService.onNotificationTap = (ruleId) {
      router.go('/rules/$ruleId/preview');
    };

    // Foreground message → show local notification (FCM doesn't auto-display)
    FirebaseMessaging.onMessage.listen((message) {
      if (message.data['type'] == 'pre_send_review') {
        LocalNotificationService.showFromFcm(message);
      }
    });

    // App opened from background notification tap
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _handleTap(router, message.data);
    });

    // FCM token refresh → re-register with backend
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
      // The auth repository handles re-registration.
      // We just need the token refresh to trigger. Auth repo listens
      // to this in the same session via AuthRepository.refreshDeviceToken.
    });
  }

  /// Called on app start to handle the case where the app was terminated
  /// and launched via a notification tap.
  static Future<void> handleInitialMessage(GoRouter router) async {
    final message = await FirebaseMessaging.instance.getInitialMessage();
    if (message != null && message.data['type'] == 'pre_send_review') {
      _handleTap(router, message.data);
    }
  }

  static void _handleTap(GoRouter router, Map<String, dynamic> data) {
    final ruleId = data['rule_id'];
    if (ruleId != null) {
      router.go('/rules/$ruleId/preview');
    }
  }
}

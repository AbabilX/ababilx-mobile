import 'dart:io' show Platform;

import 'android_ongoing_call.dart';

/// Keeps Android's MediaProjection legal while a user shares their screen.
///
/// Android 10+ requires screen capture to run inside a foreground service, and
/// Android 14+ requires that service to declare
/// `FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION` and to be running *before* the
/// projection is created.
///
/// This used to stand up a second foreground service of its own, borrowing
/// flutter_local_notifications' generic one and pinning it to
/// `foregroundServiceType="mediaProjection"` in the manifest. That meant a
/// shared call ran two independent services: the call's, and this one — with
/// the projection owned by flutter_webrtc and the service owned by a
/// notification plugin, and nothing sequencing their teardown against each
/// other. The reference app runs one service for the whole call and ORs the
/// projection type in and out of it
/// (`ActiveCallForegroundService.serviceType`), which is what
/// [AndroidOngoingCall] now does here. One lifetime, one place to end it.
class AndroidScreenShare {
  AndroidScreenShare._();

  static bool _running = false;

  static Future<void> start() async {
    if (!Platform.isAndroid || _running) return;
    await AndroidOngoingCall.setScreenSharing(true);
    _running = true;
  }

  static Future<void> stop() async {
    if (!Platform.isAndroid || !_running) return;
    _running = false;
    await AndroidOngoingCall.setScreenSharing(false);
  }
}

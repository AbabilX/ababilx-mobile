import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:permission_handler/permission_handler.dart';

import 'voice_call_log.dart';

/// Runtime permissions a 1:1 call asks for, asked so they can never hang it.
///
/// `Permission.request()` is not guaranteed to come back. permission_handler
/// refuses a second request while another is on screen (the launch-time
/// microphone prewarm, the notification prompt on a fresh install), and a
/// request whose result is lost — the Activity recreated under the dialog —
/// never completes at all. Awaited bare, either one left a first call sitting
/// on "Starting call…" until the app was restarted, by which time the grant
/// had landed and the next launch worked.
///
/// So every request is bounded, and when it fails or times out the answer is
/// read from the permission's status instead.
class CallPermissions {
  const CallPermissions._();

  /// Long enough for someone to read a system dialog and decide.
  static const requestWait = Duration(seconds: 45);

  /// How long to keep checking the status after a request could not be made
  /// because another one was already on screen.
  static const settleWait = Duration(seconds: 20);

  static bool get _resumed =>
      WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;

  /// Microphone must be granted before WebRTC capture.
  ///
  /// Requesting needs a foreground Activity; a CallKit accept from the lock
  /// screen would otherwise stall. Already-granted is checked first so the
  /// common path never touches the permission dialog.
  static Future<void> ensureMicrophone({String? callId, String? phase}) async {
    if (await Permission.microphone.isGranted) return;
    if (!_resumed) {
      voiceCallLog(
        'permission.mic.blocked',
        callId: callId,
        phase: phase,
        reason: 'not_granted_and_app_not_resumed',
      );
      throw StateError('microphone permission denied');
    }
    final granted = await request(Permission.microphone, label: 'mic');
    voiceCallLog('permission.mic', callId: callId, reason: '$granted');
    if (!granted) throw StateError('microphone permission denied');
    // Bluetooth is optional; a denied request falls back to earpiece/speaker.
    await request(Permission.bluetoothConnect, label: 'bluetooth');
  }

  /// Camera is optional on a video call: a refusal degrades to audio rather
  /// than failing the call.
  static Future<bool> ensureCamera({String? callId}) async {
    if (await Permission.camera.isGranted) return true;
    if (!_resumed) {
      voiceCallLog(
        'permission.camera.blocked',
        callId: callId,
        reason: 'app_not_resumed',
      );
      return false;
    }
    final granted = await request(Permission.camera, label: 'camera');
    voiceCallLog('permission.camera', callId: callId, reason: '$granted');
    return granted;
  }

  /// Asks for [permission] and reports whether it ended up granted, in
  /// bounded time whatever the request itself does.
  static Future<bool> request(
    Permission permission, {
    required String label,
  }) async {
    try {
      final status = await permission.request().timeout(requestWait);
      return status.isGranted;
    } on TimeoutException {
      voiceCallLog('permission.$label.timeout');
      return _isGranted(permission);
    } catch (error) {
      // Usually "a request is already running": another dialog for this app
      // is on screen. Give it a moment to be answered, then read the result.
      voiceCallLog('permission.$label.busy', reason: '$error');
      final deadline = DateTime.now().add(settleWait);
      while (DateTime.now().isBefore(deadline)) {
        if (await _isGranted(permission)) return true;
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
      return _isGranted(permission);
    }
  }

  static Future<bool> _isGranted(Permission permission) async {
    try {
      return await permission.isGranted;
    } catch (_) {
      return false;
    }
  }

  /// Ask for microphone up-front so an incoming call can be answered
  /// instantly, including from the lock screen where a dialog cannot be shown.
  static Future<void> prewarm() async {
    try {
      if (await Permission.microphone.isGranted) return;
      final granted = await request(Permission.microphone, label: 'mic');
      voiceCallLog('permission.mic.prewarm', reason: '$granted');
    } catch (_) {
      // Non-fatal: accept-time request remains the fallback.
    }
  }
}

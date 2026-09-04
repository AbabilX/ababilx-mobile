import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';

/// What the user pressed on the ongoing-call notification.
enum OngoingCallAction { hangUp, returnToCall }

/// The ongoing-call notification, and the foreground service behind it.
///
/// Backing out of the call screen used to leave a live call with no surface at
/// all: no way back to it, and no way to end it short of the other side
/// hanging up or the server sweeper expiring the call. This is the fix, shaped
/// after Signal's ongoing-call notification — tap the body to return, press
/// Hang up to end it from the shade.
///
/// The same service carries `FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION` while a
/// screen share is running (see [setScreenSharing]), which is why
/// `AndroidScreenShare` now delegates here instead of standing up a second
/// foreground service of its own.
class AndroidOngoingCall {
  AndroidOngoingCall._();

  static const _methods = MethodChannel('com.ababilx.app/ongoing_call');
  static const _events = EventChannel('com.ababilx.app/ongoing_call/events');

  static bool get _supported => !kIsWeb && Platform.isAndroid;

  static String _callId = '';
  static String _title = 'Voice call';
  static String _subtitle = 'Ongoing call';
  static bool _screenSharing = false;
  static bool _connected = true;
  static bool _running = false;

  /// Notification presses. Nothing is routed natively — only Dart knows
  /// whether the call is still live, and opening a call screen for a call that
  /// already ended is worse than ignoring the tap.
  static Stream<OngoingCallAction> get actions {
    if (!_supported) return const Stream<OngoingCallAction>.empty();
    return _events
        .receiveBroadcastStream()
        .map(_decode)
        .where((action) => action != null)
        .cast<OngoingCallAction>();
  }

  static OngoingCallAction? _decode(dynamic event) {
    if (event is! Map) return null;
    switch (event['action']?.toString()) {
      case 'hang_up':
        return OngoingCallAction.hangUp;
      case 'return_to_call':
        return OngoingCallAction.returnToCall;
      default:
        return null;
    }
  }

  /// Raise — or restate — the notification for a call in progress.
  ///
  /// [connected] drives the chronometer: an outgoing call that is still
  /// ringing has nothing to count. The CallKit plugin used to post its own
  /// "calling" entry for that phase and no longer does (see
  /// `AndroidCallParams`), so this covers it.
  static Future<void> start({
    required String callId,
    required String title,
    String subtitle = 'Ongoing call',
    bool connected = true,
  }) async {
    if (!_supported) return;
    final sameCall = _running && callId == _callId;
    _callId = callId;
    _title = title;
    _subtitle = subtitle;
    _connected = connected;
    // Only a different call resets the share flag; a phase change on the same
    // call must not drop the media-projection type mid-share.
    if (!sameCall) _screenSharing = false;
    await _send(sameCall ? 'update' : 'start');
  }

  /// Add or drop the media-projection service type as a screen share starts
  /// and stops. Starts the service if the call never registered one, so the
  /// projection type is always in place before capture begins — Android 14+
  /// requires that ordering.
  static Future<void> setScreenSharing(bool sharing) async {
    if (!_supported) return;
    if (_screenSharing == sharing && _running) return;
    _screenSharing = sharing;
    await _send(_running ? 'update' : 'start');
  }

  static Future<void> stop() async {
    if (!_supported || !_running) return;
    _running = false;
    _screenSharing = false;
    _connected = true;
    _callId = '';
    try {
      await _methods.invokeMethod<bool>('stop');
    } on PlatformException {
      // The service is already gone; the call is ending either way.
    } on MissingPluginException {
      // Older host without the channel.
    }
  }

  static Future<void> _send(String method) async {
    try {
      await _methods.invokeMethod<bool>(method, {
        'callId': _callId,
        'title': _title,
        'subtitle': _screenSharing ? 'Sharing your screen' : _subtitle,
        'screenSharing': _screenSharing,
        'connected': _connected,
      });
      _running = true;
    } on PlatformException {
      // A foreground service the OS refused to start must not take the call
      // with it — the call simply runs without a tray entry.
      _running = false;
    } on MissingPluginException {
      _running = false;
    }
  }
}

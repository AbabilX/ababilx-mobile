import 'dart:io' show Platform;

import 'package:flutter/services.dart';

/// The Android incoming-call ringtone, played by a native `MediaPlayer` that
/// belongs to the process rather than to any isolate, engine or Activity.
///
/// Two independent surfaces ring the same player, each holding it by name:
/// `native` for CallKit (raised from the FCM background isolate, released when
/// the call is answered, declined or ended) and `flutter` for the in-app call
/// screen. The tone plays while at least one holder wants it, so handing the
/// ringing UI from CallKit to the Flutter screen never interrupts the sound.
///
/// No-op off Android: iOS rings through CallKit and the bundled asset.
class CallRinger {
  const CallRinger._();

  static const _channel = MethodChannel('com.ababilx.app/call_ringer');

  /// Ring on behalf of [holder]. Idempotent.
  ///
  /// Pass [requireNotificationUi] for a hold whose ringing surface is a
  /// notification: with notifications turned off the call has no answer or
  /// decline control, so the request is dropped instead of ringing blind.
  static Future<void> hold(
    String holder, {
    bool requireNotificationUi = false,
  }) => _invoke('hold', holder, requireNotificationUi);

  /// Ring on behalf of [holder], restarting the tone from the top.
  static Future<void> restart(
    String holder, {
    bool requireNotificationUi = false,
  }) => _invoke('restart', holder, requireNotificationUi);

  /// Stop ringing for [holder]; other holders keep the tone alive.
  static Future<void> release(String holder) => _invoke('release', holder);

  /// Stop ringing outright, whoever asked for it.
  static Future<void> releaseAll() => _invoke('releaseAll', null);

  /// Quiet the ring without ending the call — the Silence button, and the
  /// same thing a volume key does natively. Stays quiet for the rest of this
  /// ring, across the CallKit to in-app hand-off.
  static Future<void> silence() => _invoke('silence', null);

  /// This phone is in [callId] (placing, answering or talking); null = idle.
  ///
  /// Signal's busy rule, kept in the process so the FCM isolate obeys it too:
  /// entering a call stops any ring at once, and no ring may start until the
  /// call is left. Call only from the engine that holds the call — the native
  /// side clears it when that engine goes away.
  static Future<void> setLiveCall(String? callId) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('setLiveCall', {'callId': callId});
    } on PlatformException {
      // Never take a call down over the busy flag.
    } on MissingPluginException {
      // Engine without this plugin — nothing rings there either.
    }
  }

  /// The call this phone is in, from any isolate; null when idle or unknown.
  static Future<String?> liveCall() async {
    if (!Platform.isAndroid) return null;
    try {
      return await _channel.invokeMethod<String>('liveCall');
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  static Future<void> _invoke(
    String method,
    String? holder, [
    bool requireNotificationUi = false,
  ]) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>(method, {
        'holder': ?holder,
        'requireNotificationUi': requireNotificationUi,
      });
    } on PlatformException {
      // Ringing must never take a call down with it.
    } on MissingPluginException {
      // Engine without this plugin registered — nothing is ringing there.
    }
  }
}

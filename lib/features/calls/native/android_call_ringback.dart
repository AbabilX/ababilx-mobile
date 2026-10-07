import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';

import '../providers/voice_call_state.dart';
import '../voice_call_log.dart';

/// The caller's ringback ("tuut… tuut…") while the other phone rings —
/// Signal's `OutgoingRinger` (looping MediaPlayer on the voice-communication
/// usage), native in `CallRingback.kt`.
///
/// Plays only while the screen says "Ringing…" — the callee's phone has
/// reported that it rings (`calleeRingingAt`). "Calling…" stays silent, as in
/// WhatsApp, so the tone never claims a ring that is not happening. A callee
/// in privacy mode never reports ringing, so that caller hears nothing: the
/// user's call (2026-09-29). Stops the moment the call is answered, before
/// media opens — the native side hands the audio mode back, and LiveKit must
/// find the mode it was in before the call.
///
/// The same player carries the connecting tone: a short "pip-pip" on both
/// phones while the screen says "Exchanging security keys…" (`connecting`),
/// as Telegram does. It ends the moment the call is connected, failed or over.
///
/// No-op off Android. iOS is not a target yet.
class AndroidCallRingback {
  const AndroidCallRingback._();

  static const MethodChannel _channel = MethodChannel(
    'com.ababilx.app/call_ringback',
  );

  static bool get _supported => !kIsWeb && Platform.isAndroid;

  /// What was last sent: null = silent, else `tone|speaker`.
  static String? _playing;

  /// Whether [state] is a call whose caller should hear ringback.
  static bool wants(VoiceCallState state) =>
      state.phase == VoiceCallPhase.outgoingRinging &&
      state.call?.calleeRingingAt != null;

  /// The tone [state] should be playing, or null for silence.
  static String? toneFor(VoiceCallState state) {
    if (wants(state)) return 'ringback';
    if (state.phase == VoiceCallPhase.connecting) return 'connecting';
    return null;
  }

  static Future<void> sync(VoiceCallState state) {
    final tone = toneFor(state);
    if (tone != null) return _start(tone: tone, speaker: state.speaker);
    if (_playing != null) {
      voiceCallLog(
        'ringback.stop',
        callId: state.call?.id,
        phase: state.phase.name,
        reason: 'ringing=${state.call?.calleeRingingAt != null}',
      );
    }
    return stop();
  }

  static Future<void> _start({
    required String tone,
    required bool speaker,
  }) async {
    final key = '$tone|$speaker';
    if (!_supported || _playing == key) return;
    voiceCallLog('ringback.start', reason: 'tone=$tone speaker=$speaker');
    _playing = key;
    await _invoke('start', {'tone': tone, 'speaker': speaker});
  }

  static Future<void> stop() async {
    if (!_supported || _playing == null) return;
    _playing = null;
    await _invoke('stop', null);
  }

  static Future<void> _invoke(String method, Object? args) async {
    try {
      await _channel.invokeMethod<void>(method, args);
    } on PlatformException {
      // A failed tone is a quiet call, never a failed one.
    } on MissingPluginException {
      // Older host without the channel.
    }
  }
}

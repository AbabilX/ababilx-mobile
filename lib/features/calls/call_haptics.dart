import 'dart:io';

import 'package:flutter/services.dart';

import 'providers/voice_call_state.dart';

/// The moments of a call worth feeling.
enum CallHaptic { connected, declined, peerDeclined, mute, unmute }

/// A buzz for [CallHaptic], played by the Vibrator on Android
/// (`CallHapticsChannel.kt`): Flutter's HapticFeedback is faint or silent on
/// many phones there. Elsewhere the closest HapticFeedback stands in.
abstract final class CallHaptics {
  static const _channel = MethodChannel('com.ababilx.app/call_haptics');

  static void buzz(CallHaptic kind) {
    if (!Platform.isAndroid) {
      switch (kind) {
        case CallHaptic.connected || CallHaptic.peerDeclined:
          HapticFeedback.heavyImpact();
        case CallHaptic.declined:
          HapticFeedback.mediumImpact();
        case CallHaptic.mute || CallHaptic.unmute:
          HapticFeedback.lightImpact();
      }
      return;
    }
    _channel
        .invokeMethod<void>('buzz', {'kind': kind.name})
        .catchError((_) {});
  }
}

/// Which buzz, if any, the step from [prev] to [next] earns. Read off state,
/// not off buttons, so an answer on the lock screen, a decline from the
/// notification or the other side declining is felt like a tap in the app.
CallHaptic? voiceCallHaptic(VoiceCallState prev, VoiceCallState next) {
  final call = next.call;
  if (call == null) return null;
  final sameCall = prev.call?.id == call.id;
  if (prev.phase != VoiceCallPhase.connected &&
      next.phase == VoiceCallPhase.connected) {
    return CallHaptic.connected;
  }
  final declined = call.status == 'declined';
  if (declined && !(sameCall && prev.call?.status == 'declined')) {
    // On the caller's phone the other side said no; on the callee's, this
    // phone did.
    return next.outgoing ? CallHaptic.peerDeclined : CallHaptic.declined;
  }
  // A new call starts unmuted: that reset is not a press.
  if (sameCall && prev.muted != next.muted) {
    return next.muted ? CallHaptic.mute : CallHaptic.unmute;
  }
  return null;
}

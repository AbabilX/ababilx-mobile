import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Speaker / earpiece through Android Telecom, for a call Telecom is hosting.
///
/// flutter_callkit_incoming registers every ring it shows as a self-managed
/// Telecom call, and Answer on its screen — the lock screen, the heads-up
/// notification — makes that call active. Telecom then owns the audio mode,
/// and Android applies only the mode owner's route: LiveKit's speaker request
/// is dropped without an error, which is why Speaker did nothing on a call
/// answered from the lock screen. Native side: `CallAudioTelecom.kt`.
///
/// Answers false when Telecom is not hosting [callId] — answered in the app,
/// placed from it, or not Android — and the caller's LiveKit route is the one
/// that counts.
class TelecomAudioRoute {
  const TelecomAudioRoute._();

  static const MethodChannel _channel = MethodChannel(
    'com.ababilx.app/call_audio_telecom',
  );

  static Future<bool> route(String? callId, {required bool speaker}) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return false;
    }
    if (callId == null || callId.isEmpty) return false;
    try {
      final handled = await _channel.invokeMethod<bool>('route', {
        'callId': callId,
        'speaker': speaker,
      });
      return handled ?? false;
    } on MissingPluginException {
      // A host without the channel has no Telecom route to offer.
      return false;
    } on PlatformException {
      return false;
    }
  }
}

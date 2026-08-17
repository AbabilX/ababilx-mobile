import 'call_ringtone.dart';

/// In-app incoming ringtone for the 1:1 DM call screen (foreground).
///
/// Background / lock-screen ringing is handled by CallKit
/// (`ringtonePath: clear_agenda`). This covers the path where CallStoreSync
/// opens `/call` while the app is focused and CallKit is skipped.
///
/// Delegates to [CallRingtone] so the DM tone and a channel group-call tone are
/// the same bundled asset and can never stack on top of each other.
class IncomingCallRingtone {
  IncomingCallRingtone._();

  static const _holder = 'dm';

  static Future<void> start() => CallRingtone.hold(_holder);

  /// Hold and play from the top even if this holder was already ringing — for
  /// the hand-off from the native CallKit ringer to the in-app one.
  static Future<void> restart() async {
    await CallRingtone.hold(_holder);
    await CallRingtone.refresh();
  }

  static Future<void> stop() => CallRingtone.release(_holder);
}

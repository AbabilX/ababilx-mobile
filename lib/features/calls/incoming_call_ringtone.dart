import 'call_ringtone.dart';

/// In-app incoming ringtone for the 1:1 DM call screen (foreground).
///
/// Background / lock-screen ringing is raised by CallKit, but on Android the
/// sound itself comes from the same native player either way (`CallRinger.kt`,
/// held as `native` there and `flutter` here). This covers the path where
/// CallStoreSync opens `/call` while the app is focused and CallKit is
/// skipped.
///
/// Delegates to [CallRingtone] so the DM tone and a channel group-call tone are
/// the same bundled asset and can never stack on top of each other.
class IncomingCallRingtone {
  IncomingCallRingtone._();

  static const _holder = 'dm';

  static Future<void> start() => CallRingtone.hold(_holder);

  static Future<void> stop() => CallRingtone.release(_holder);
}

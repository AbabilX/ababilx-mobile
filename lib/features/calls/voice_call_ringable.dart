import 'data/models/voice_call.dart';

/// Whether a call row still justifies a ringing surface on this device.
///
/// The server row is the authority, never the push or the CallKit record: both
/// outlive the call they announced. A locked phone keeps flutter_callkit_
/// incoming's full-screen Activity until its own timer expires, so an offer the
/// caller cancelled can still be answered by hand minutes later — and the
/// answer arrives as an ordinary CallKit accept, indistinguishable from a real
/// one until this is checked.
bool isVoiceCallRingable(VoiceCall call, {DateTime? now}) =>
    !call.isTerminal &&
    call.status == 'ringing' &&
    call.expiresAt.isAfter(now ?? DateTime.now());

enum IncomingCallAdmission { show, restoreRinging, ignoreAccepted, ignoreBusy }

class NativeCallSnapshot {
  const NativeCallSnapshot({required this.id, required this.isAccepted});

  final String id;
  final bool isAccepted;
}

/// Signal-style admission: an offer cannot ring while an existing call is
/// active, and a duplicate offer for an accepted call is never allowed to
/// reacquire audio focus.
IncomingCallAdmission decideIncomingCallAdmission(
  String incomingCallId,
  Iterable<NativeCallSnapshot> activeCalls,
) {
  final calls = activeCalls.toList(growable: false);
  for (final call in calls) {
    if (call.id != incomingCallId) continue;
    return call.isAccepted
        ? IncomingCallAdmission.ignoreAccepted
        : IncomingCallAdmission.restoreRinging;
  }
  return calls.isEmpty
      ? IncomingCallAdmission.show
      : IncomingCallAdmission.ignoreBusy;
}

/// Whether CallKit already holds [callId] as accepted.
///
/// The plugin does not replay an Accept it emitted while this isolate was in
/// the background, so this persisted flag is the only record of that press
/// once the app comes forward. Missing it left the app ringing at a call the
/// user had already answered, asking for a second Accept.
bool nativeCallWasAccepted(
  String callId,
  Iterable<NativeCallSnapshot> activeCalls,
) {
  if (callId.isEmpty) return false;
  for (final call in activeCalls) {
    if (call.id == callId) return call.isAccepted;
  }
  return false;
}

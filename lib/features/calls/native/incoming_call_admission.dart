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

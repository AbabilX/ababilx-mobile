import 'providers/voice_call_state.dart';

/// What the ongoing-call notification says for a 1:1 call, or null for the
/// phases that get no tray entry at all.
///
/// `incomingRinging` is absent on purpose: CallKit owns the ringing surface,
/// and a second entry beside it is the duplicate this whole path exists to
/// avoid. The ringing-out phases *are* here because the CallKit plugin no
/// longer posts its own "calling" notification — see `AndroidCallParams`.
String? ongoingCallSubtitle(VoiceCallPhase phase) => switch (phase) {
  VoiceCallPhase.outgoingRinging => 'Calling…',
  VoiceCallPhase.connecting => 'Connecting…',
  VoiceCallPhase.connected => 'Ongoing call',
  _ => null,
};

/// Whether that notification should run a chronometer. Only a connected call
/// has something to count; a timer beside "Calling…" reads as a call already
/// in progress.
bool ongoingCallUsesChronometer(VoiceCallPhase phase) =>
    phase == VoiceCallPhase.connected;

import 'providers/voice_call_state.dart';

/// The one line under the caller's name.
///
/// Pure so it can be tested without a widget tree, and so the call screen and
/// the picture-in-picture window can never disagree about what a call is
/// currently doing.
String voiceCallStatusText(VoiceCallState state) {
  switch (state.phase) {
    case VoiceCallPhase.idle:
      return 'Call finished';
    case VoiceCallPhase.starting:
      return 'Starting call…';
    case VoiceCallPhase.outgoingRinging:
      return 'Calling…';
    case VoiceCallPhase.incomingRinging:
      return 'Incoming call…';
    case VoiceCallPhase.connecting:
      return 'Connecting…';
    case VoiceCallPhase.connected:
      return formatCallDuration(state.connectedAt);
    case VoiceCallPhase.ended:
      final status = state.call?.status;
      // Caller sees a formal busy message when the peer declines.
      if (status == 'declined' && state.outgoing) {
        return '${state.peerName} is busy right now';
      }
      if (status == 'declined') return 'Call declined';
      if (status == 'cancelled') return 'Call cancelled';
      if (status == 'missed') return 'No answer';
      final lasted = formatCallDuration(state.connectedAt);
      return lasted == '00:00' ? 'Call ended' : 'Call ended · $lasted';
    case VoiceCallPhase.failed:
      return 'Call failed';
  }
}

/// mm:ss, or hh:mm:ss once a call passes an hour.
String formatCallDuration(DateTime? started, {DateTime? now}) {
  if (started == null) return '00:00';
  final duration = (now ?? DateTime.now()).difference(started);
  final total = duration.inSeconds.clamp(0, 24 * 3600);
  final minutes = (total ~/ 60).toString().padLeft(2, '0');
  final seconds = (total % 60).toString().padLeft(2, '0');
  if (total >= 3600) {
    final hours = (total ~/ 3600).toString().padLeft(2, '0');
    final m = ((total % 3600) ~/ 60).toString().padLeft(2, '0');
    return '$hours:$m:$seconds';
  }
  return '$minutes:$seconds';
}

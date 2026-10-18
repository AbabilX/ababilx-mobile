import '../calls/group/providers/group_call_state.dart';
import '../calls/providers/voice_call_state.dart';

/// Whether the realtime socket must stay up while the app is in the
/// background — Signal's keep-alive tokens, as one rule.
///
/// Only live sessions hold it, because each one carries its signalling over
/// the socket: a 1:1 call's offer, answer and ICE candidates (a backgrounded
/// call is still a call — the user switched apps or locked the screen), a
/// group call's roster and screen-share handovers, a Ghost Chat's sealed
/// signals. Everything else is delivered by FCM when the socket is gone.
bool socketHeldInBackground({
  required VoiceCallPhase voice,
  required GroupCallPhase group,
  required bool ghostInSession,
  bool historyLiveOpen = false,
}) {
  final voiceLive = switch (voice) {
    VoiceCallPhase.idle ||
    VoiceCallPhase.ended ||
    VoiceCallPhase.failed => false,
    _ => true,
  };
  final groupLive = switch (group) {
    GroupCallPhase.lobby ||
    GroupCallPhase.joining ||
    GroupCallPhase.connected => true,
    _ => false,
  };
  // A linked computer reading this phone's chats: its WebRTC restarts and
  // wakes travel over the socket, and a dataSync service keeps us running.
  return voiceLive || groupLive || ghostInSession || historyLiveOpen;
}

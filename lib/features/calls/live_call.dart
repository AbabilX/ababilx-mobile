import 'group/providers/group_call_state.dart';
import 'providers/voice_call_state.dart';

/// The call this phone is in, for Signal's busy rule — or null when idle.
///
/// Signal accepts a new incoming call only from `IdleActionProcessor`; every
/// other state is busy. Ours are the phases in which this device holds a call
/// of its own: placing one (it is ringing on the other end), answering one
/// and talking. A ring in progress is NOT live — that is the call being
/// offered, and it must keep ringing. A lobby has joined nothing yet.
///
/// The DM call wins when both exist, as everywhere else: its audio is the one
/// on the earpiece.
String? liveCallId(VoiceCallState dm, GroupCallState group) {
  final dmLive = switch (dm.phase) {
    VoiceCallPhase.outgoingRinging ||
    VoiceCallPhase.connecting ||
    VoiceCallPhase.connected => true,
    _ => false,
  };
  final dmId = dm.call?.id ?? '';
  if (dmLive && dmId.isNotEmpty) return dmId;
  final groupLive = switch (group.phase) {
    GroupCallPhase.joining || GroupCallPhase.connected => true,
    _ => false,
  };
  final groupId = group.call?.id ?? '';
  if (groupLive && groupId.isNotEmpty) return groupId;
  return null;
}

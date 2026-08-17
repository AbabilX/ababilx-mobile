import 'dart:async';

import '../../call_ringtone.dart';
import '../data/models/group_call.dart';

/// A group call rings for one minute, then declines itself.
const groupCallRingWindow = Duration(seconds: 60);

/// How much of the ring window a call has left. The server replays live calls
/// when a socket connects, so an event can arrive long after the call began —
/// that one must not ring, it should just sit in the channel header as "Join".
Duration groupCallRingTimeLeft(GroupCall call) {
  final left = groupCallRingWindow - DateTime.now().difference(call.startedAt);
  // Clamped because the device clock is not the server's.
  return left > groupCallRingWindow ? groupCallRingWindow : left;
}

/// Owns the ringing-invite lifecycle for channel group calls: the ring window,
/// the shared ringtone hold, and the per-call "already answered" memory.
///
/// Declining is local only — the server keeps no per-member invite state for
/// group calls, so a decline silences this device and nothing else. The call
/// keeps running and the channel header still offers "Join".
class GroupCallInvites {
  GroupCallInvites({required this.onChanged});

  static const _ringtoneHolder = 'group';

  final void Function(GroupCall? invite) onChanged;
  final Set<String> _answered = {};
  Timer? _timer;
  GroupCall? _invite;
  bool _localRing = true;

  GroupCall? get invite => _invite;

  /// Silences the in-app tone while the native CallKit screen is ringing
  /// instead — two players would fight for audio focus and one would drop out.
  void setLocalRing(bool enabled) {
    if (_localRing == enabled) return;
    _localRing = enabled;
    _applyRingtone();
  }

  /// Ring for [call] unless this device started it, already answered it, or the
  /// call is older than the ring window.
  void offer(GroupCall call, {required String currentUserId}) {
    if (call.startedBy == currentUserId) return;
    if (_answered.contains(call.id)) return;
    if (_invite?.id == call.id) return;
    final left = groupCallRingTimeLeft(call);
    if (left <= Duration.zero) return;
    _set(call);
    _timer?.cancel();
    _timer = Timer(left, dismiss);
  }

  /// Remember [callId] as answered without there being a ringing invite —
  /// joining from the channel header must also stop a later socket replay of
  /// that same call from ringing.
  void markAnswered(String callId) {
    _answered.add(callId);
    withdraw(callId);
  }

  /// Stop ringing for [callId] because it ended or was superseded.
  void withdraw(String callId) {
    if (_invite?.id != callId) return;
    _set(null);
  }

  /// Answering — join, deny, or joining another call from the channel header —
  /// stops this call ringing here again for the rest of the session.
  void dismiss() {
    final current = _invite;
    if (current != null) _answered.add(current.id);
    _set(null);
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
    _invite = null;
    unawaited(CallRingtone.release(_ringtoneHolder));
  }

  void _set(GroupCall? call) {
    if (call == null) {
      _timer?.cancel();
      _timer = null;
    }
    _invite = call;
    _applyRingtone();
    onChanged(call);
  }

  void _applyRingtone() {
    unawaited(
      _invite != null && _localRing
          ? CallRingtone.hold(_ringtoneHolder)
          : CallRingtone.release(_ringtoneHolder),
    );
  }
}

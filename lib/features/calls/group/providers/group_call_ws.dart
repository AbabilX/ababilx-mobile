part of 'group_call_provider.dart';

/// Real-time `group_call.*` fan-out plus the room→state projection.
mixin GroupCallWs on GroupCallBase, GroupCallLifecycle, GroupCallMedia {
  void handleWsEvent(Map<String, dynamic> event) {
    final type = event['type'] as String? ?? '';
    if (!type.startsWith('group_call.')) return;
    final payload = event['group_call'];
    if (payload is! Map) return;
    final call = GroupCall.fromJson(Map<String, dynamic>.from(payload));
    final ended = type == 'group_call.ended';

    if (ended) {
      _invites?.withdraw(call.id);
    } else if (type == 'group_call.started' && !state.active) {
      // The server also replays this on socket connect, so a device that was
      // backgrounded or restarted still gets its invite. GroupCallInvites
      // decides whether it is still inside the ring window.
      //
      // Skipped while already in a call: a socket reconnect replays the call
      // this device is sitting in, which must not ring at itself.
      _invites?.offer(call, currentUserId: _currentUserId);
    }

    rememberActiveCall(call.conversationId, ended ? null : call);

    if (state.call?.id != call.id) return;
    if (ended) {
      unawaited(clearRoom());
      return;
    }
    applyCall(call);
    unawaited(yieldScreenShareIfTakenOver(call));
  }

  /// Updates the header map, and the in-call copy when it is the same call.
  @override
  void applyCall(GroupCall call) {
    rememberActiveCall(call.conversationId, call.active ? call : null);
    if (state.call?.id != call.id) return;
    state = state.copyWith(call: call);
    syncRoom();
  }

  void rememberActiveCall(String conversationId, GroupCall? call) {
    final next = Map<String, GroupCall>.from(state.activeCalls);
    if (call == null || !call.active) {
      if (next.remove(conversationId) == null) return;
    } else {
      next[conversationId] = call;
    }
    state = state.copyWith(activeCalls: next);
  }

  /// Projects the live room onto the view state. No-ops unless a room and call
  /// are still current, so a late event from a torn-down room cannot resurrect
  /// the call UI.
  @override
  void syncRoom() {
    final room = _room;
    final call = state.call;
    if (room == null || call == null) return;
    final snapshot = groupRoomSnapshot(room, screenOwnerId: call.screenSharerId);
    state = state.copyWith(
      participants: snapshot.participants,
      screen: snapshot.screen,
      clearScreen: snapshot.screen == null,
      muted: snapshot.muted,
      sharingScreen: snapshot.sharingScreen,
    );
  }
}

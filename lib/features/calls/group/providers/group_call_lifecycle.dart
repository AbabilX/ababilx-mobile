part of 'group_call_provider.dart';

/// Room teardown and server-side leave bookkeeping.
mixin GroupCallLifecycle on GroupCallBase {
  Future<void> onRoomDisconnected(Room room) async {
    if (_room != room) return;
    final call = state.call;
    await clearRoom(error: 'The group call disconnected.');
    if (call != null) await leaveOnce(call.id);
  }

  /// Leaving is idempotent: the room teardown, an explicit tap and the
  /// disconnect handler can all race on the same call.
  Future<void> leaveOnce(String callId) async {
    if (_leftCallIds.contains(callId)) return;
    _leftCallIds.add(callId);
    try {
      final call = await _repository.leave(callId);
      if (call != null) applyCall(call);
    } on GroupCallApiException {
      // Already gone server-side — nothing left to release.
    } catch (_) {}
  }

  Future<void> clearRoom({String? error}) async {
    final room = _room;
    final callId = state.call?.id;
    _room = null;
    // Drop the ongoing notification with the room, so the foreground service
    // does not outlive the call it is keeping alive.
    if (callId != null) await AndroidGroupCallUi.endOngoing(callId);
    await _binding?.detach();
    _binding = null;
    await _screenShare?.reset();
    if (room != null) {
      unawaited(
        room.disconnect().whenComplete(() => unawaited(room.dispose())),
      );
    }
    state = state.copyWith(
      phase: error == null ? GroupCallPhase.idle : GroupCallPhase.failed,
      clearCall: true,
      clearScreen: true,
      participants: const [],
      muted: false,
      sharingScreen: false,
      screenSharePending: false,
      microphoneUnavailable: false,
      error: error,
      clearError: error == null,
    );
  }

  /// Implemented by [GroupCallWs] — declared here so the mixins stay decoupled.
  void applyCall(GroupCall call);
}

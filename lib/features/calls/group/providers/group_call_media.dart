part of 'group_call_provider.dart';

/// Microphone, speaker routing and screen sharing while connected.
mixin GroupCallMedia on GroupCallBase {
  Future<void> toggleMute() async {
    final room = _room;
    if (room == null || state.microphoneUnavailable) return;
    await room.localParticipant?.setMicrophoneEnabled(state.muted);
    syncRoom();
  }

  Future<void> toggleSpeaker() async {
    final next = !state.speaker;
    await AudioManager.instance.setSpeakerOutputPreferred(next);
    state = state.copyWith(speaker: next);
  }

  Future<void> toggleScreenShare() async {
    final room = _room;
    final call = state.call;
    final sharer = _screenShare;
    if (room == null || call == null || sharer == null || sharer.busy) return;
    state = state.copyWith(screenSharePending: true);
    try {
      final updated = state.sharingScreen
          ? await sharer.stop(room, call)
          : await sharer.start(room, call);
      if (updated != null) applyCall(updated);
      syncRoom();
    } catch (error) {
      state = state.copyWith(error: groupScreenShareErrorMessage(error));
      syncRoom();
    } finally {
      state = state.copyWith(screenSharePending: false);
    }
  }

  /// Listen-only is a valid state: no microphone (or a refused permission)
  /// must not fail the join, it just disables the mute button.
  Future<bool> enableMicrophone(Room room) async {
    try {
      final publication = await room.localParticipant?.setMicrophoneEnabled(
        true,
      );
      return publication?.track != null;
    } catch (_) {
      return false;
    }
  }

  /// LiveKit dropped the local capture (system "Stop sharing", or a takeover),
  /// so the server-side claim has to be handed back.
  Future<void> onLocalTrackUnpublished(TrackSource source) async {
    final updated = await _screenShare?.handleUnpublished(source, state.call);
    if (updated != null) applyCall(updated);
    syncRoom();
  }

  /// Another member claimed the stage while we were still publishing — drop the
  /// local capture so two screens never fight for it.
  Future<void> yieldScreenShareIfTakenOver(GroupCall call) async {
    final room = _room;
    final owner = call.screenSharerId;
    if (room == null || !state.sharingScreen || owner == null) return;
    if (owner == room.localParticipant?.identity) return;
    await _screenShare?.yieldTo(room);
    syncRoom();
  }

  /// Implemented by [GroupCallWs].
  void applyCall(GroupCall call);
  void syncRoom();
}

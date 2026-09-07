part of 'group_call_provider.dart';

/// The pre-join lobby. Nothing here touches the server: opening it joins no
/// room and starts no call, so backing out costs everyone else nothing.
mixin GroupCallLobby on GroupCallBase {
  void openLobby(String conversationId, {String? conversationName}) {
    if (_room != null || _joinPending) return;
    state = state.copyWith(
      phase: GroupCallPhase.lobby,
      clearCall: true,
      clearScreen: true,
      participants: const [],
      hands: const {},
      reactions: const [],
      clearError: true,
      lobby: GroupLobbyView(
        conversationId: conversationId,
        conversationName: conversationName?.trim().isNotEmpty == true
            ? conversationName!.trim()
            : 'Group call',
        call: state.activeCalls[conversationId],
        // Keep the microphone choice if the lobby is reopened in one sitting.
        joinMuted: state.lobby?.joinMuted ?? false,
      ),
    );
    unawaited(refresh(conversationId));
  }

  void cancelLobby() {
    if (state.phase != GroupCallPhase.lobby) return;
    state = state.copyWith(phase: GroupCallPhase.idle, clearLobby: true);
  }

  void setLobbyMuted(bool muted) {
    final lobby = state.lobby;
    if (lobby == null) return;
    state = state.copyWith(lobby: lobby.copyWith(joinMuted: muted));
  }

  /// Implemented by the notifier.
  Future<void> refresh(String conversationId);
}

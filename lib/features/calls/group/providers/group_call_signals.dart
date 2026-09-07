part of 'group_call_provider.dart';

/// Hands and reactions for the connected room. State is per-connection on
/// purpose — a hand raised in a call the user left means nothing, so nothing
/// is persisted and nothing survives [clearRoom].
mixin GroupCallSignals on GroupCallBase {
  void publishSignal(CallSignal signal) {
    final local = _room?.localParticipant;
    if (local == null) return;
    unawaited(
      local
          .publishData(
            encodeCallSignal(signal),
            reliable: true,
            topic: callSignalTopic,
          )
          .catchError((_) {}),
    );
  }

  void applySignal(CallSignal signal, String identity, String name) {
    switch (signal) {
      case HandSignal(:final raised):
        final hands = Map<String, DateTime>.from(state.hands);
        if (raised) {
          hands.putIfAbsent(identity, DateTime.now);
        } else {
          hands.remove(identity);
        }
        state = state.copyWith(hands: hands);
      case ReactionSignal(:final emoji):
        final reactions = [
          ...state.reactions.length > 11
              ? state.reactions.sublist(state.reactions.length - 11)
              : state.reactions,
          GroupCallReaction(
            id: '$identity-${DateTime.now().microsecondsSinceEpoch}',
            identity: identity,
            name: name,
            emoji: emoji,
            at: DateTime.now(),
          ),
        ];
        state = state.copyWith(reactions: reactions);
        _scheduleReactionSweep();
    }
  }

  void _scheduleReactionSweep() {
    _reactionSweep?.cancel();
    _reactionSweep = Timer(reactionTtl, () {
      final cutoff = DateTime.now().subtract(reactionTtl);
      final alive = state.reactions
          .where((reaction) => reaction.at.isAfter(cutoff))
          .toList();
      state = state.copyWith(reactions: alive);
      if (alive.isNotEmpty) _scheduleReactionSweep();
    });
  }

  void toggleHand() {
    final local = _room?.localParticipant;
    if (local == null) return;
    final raised = !state.hands.containsKey(local.identity);
    publishSignal(HandSignal(raised));
    applySignal(
      HandSignal(raised),
      local.identity,
      local.name.isEmpty ? local.identity : local.name,
    );
  }

  void sendReaction(String emoji) {
    final local = _room?.localParticipant;
    if (local == null) return;
    publishSignal(ReactionSignal(emoji));
    applySignal(
      ReactionSignal(emoji),
      local.identity,
      local.name.isEmpty ? local.identity : local.name,
    );
  }

  void onSignalData(DataReceivedEvent event) {
    if (event.topic != null && event.topic != callSignalTopic) return;
    final signal = decodeCallSignal(event.data);
    final sender = event.participant;
    if (signal == null || sender == null) return;
    applySignal(
      signal,
      sender.identity,
      sender.name.isEmpty ? sender.identity : sender.name,
    );
  }

  /// A late joiner missed every hand already up, and only the raiser can answer
  /// for its own hand — so re-announce ours whenever somebody arrives.
  void onParticipantJoined() {
    final identity = _room?.localParticipant?.identity;
    if (identity != null && state.hands.containsKey(identity)) {
      publishSignal(const HandSignal(true));
    }
  }

  void onParticipantLeft(String identity) {
    if (!state.hands.containsKey(identity)) return;
    final hands = Map<String, DateTime>.from(state.hands)..remove(identity);
    state = state.copyWith(hands: hands);
  }

  void resetSignals() {
    _reactionSweep?.cancel();
    _reactionSweep = null;
  }
}

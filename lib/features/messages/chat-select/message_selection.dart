import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Which messages a long press → Select has put into multi-select mode.
///
/// The reference app keeps this on the conversation adapter; here it is a
/// provider so the header, the list and the action bar — three sibling subtrees
/// — read one truth. **Ids only, never message copies**: a stored copy goes
/// stale the moment an edit, a delete or a send confirmation lands, and every
/// action has to run against the row as it is now.
class MessageSelection {
  const MessageSelection({required this.conversationId, this.ids = const {}});

  const MessageSelection.none() : conversationId = '', ids = const {};

  final String conversationId;

  /// Insertion-ordered, but nothing reads that order: actions sort by the
  /// timeline instead, so a forward or a copy reads oldest first however the
  /// taps happened to fall.
  final Set<String> ids;

  bool get isActive => ids.isNotEmpty;

  bool contains(String id) => ids.contains(id);

  bool isActiveIn(String conversationId) =>
      isActive && this.conversationId == conversationId;

  MessageSelection _with(Set<String> next) => next.isEmpty
      ? const MessageSelection.none()
      : MessageSelection(conversationId: conversationId, ids: next);
}

class MessageSelectionNotifier extends Notifier<MessageSelection> {
  @override
  MessageSelection build() => const MessageSelection.none();

  /// Entering the mode from the long-press menu. A selection never spans two
  /// conversations, so starting in one clears whatever the other held.
  void start({required String conversationId, required String messageId}) {
    state = MessageSelection(conversationId: conversationId, ids: {messageId});
  }

  void toggle({required String conversationId, required String messageId}) {
    if (state.conversationId != conversationId) {
      start(conversationId: conversationId, messageId: messageId);
      return;
    }
    final next = Set<String>.from(state.ids);
    if (!next.remove(messageId)) next.add(messageId);
    state = state._with(next);
  }

  void clear() {
    if (state.isActive) state = const MessageSelection.none();
  }

  /// Drops ids the timeline no longer holds — a message deleted from another
  /// device, or one that expired out of the feed. The reference app does the
  /// same on `onItemRangeRemoved`; without it the count keeps promising rows
  /// the actions can no longer act on, and an empty selection would leave the
  /// bars up over a conversation with nothing selected.
  void retain(Set<String> presentIds) {
    if (!state.isActive) return;
    final kept = state.ids.where(presentIds.contains).toSet();
    if (kept.length != state.ids.length) state = state._with(kept);
  }
}

final messageSelectionProvider =
    NotifierProvider<MessageSelectionNotifier, MessageSelection>(
      MessageSelectionNotifier.new,
    );

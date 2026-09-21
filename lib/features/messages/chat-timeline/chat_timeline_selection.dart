import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../chat-select/message_selection.dart';
import '../data/models/chat_models.dart';
import 'chat_timeline.dart';

mixin ChatTimelineSelection on ConsumerState<ChatTimeline> {
  /// Drops selected ids the feed no longer carries — a message deleted from
  /// another device, or one that fell out of the loaded page. Signal does the
  /// same on `onItemRangeRemoved`; without it the count keeps promising rows
  /// no action can reach. Deferred a frame because it writes to a provider.
  void pruneSelection(List<ChatMessage> messages) {
    if (!ref.read(messageSelectionProvider).isActiveIn(widget.conversationId)) {
      return;
    }
    final present = messages.map((m) => m.id).toSet();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(messageSelectionProvider.notifier).retain(present);
    });
  }
}

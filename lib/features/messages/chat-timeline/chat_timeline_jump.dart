import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/chat_provider.dart';
import 'chat_timeline.dart';
import 'timeline_jump.dart';

/// Tapping a quote scrolls to the message it answers. The walk itself is
/// [TimelineJumpController]; this is where it gets the list's scroll position
/// and the feed's paging.
mixin ChatTimelineJump on ConsumerState<ChatTimeline> {
  ScrollController get timelineScrollController;

  TimelineJumpController? _jump;

  TimelineJumpController get jumpController => _jump ??= TimelineJumpController(
    scroll: timelineScrollController,
    // Read through `widget` on every call, not captured once: the same
    // state serves the next conversation after a deep link.
    loadOlder: () => ref
        .read(chatProvider.notifier)
        .loadMoreFeed(widget.conversationId, threadRootId: widget.threadRootId),
  );

  Widget jumpScope({required Widget child}) =>
      TimelineJumpScope(controller: jumpController, child: child);

  void disposeJump() {
    _jump?.dispose();
    _jump = null;
  }
}

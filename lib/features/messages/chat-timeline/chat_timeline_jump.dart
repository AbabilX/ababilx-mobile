import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../chat_utils.dart';
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
    loadOlder: _loadOlder,
  );

  /// Read through `widget` on every call, not captured once: the same state
  /// serves the next conversation after a deep link.
  Future<void> _loadOlder() async {
    await ref
        .read(chatProvider.notifier)
        .loadMoreFeed(widget.conversationId, threadRootId: widget.threadRootId);
    await _olderPageSettled();
  }

  /// The walk jumps to the top of what is loaded, which is exactly where the
  /// list's own scroll listener starts fetching the page before it. The call
  /// above then returns at once — a page is already in flight — and reading
  /// that as "no more history" made every jump past one page report the
  /// message as gone. So wait for whichever load is running to land.
  Future<void> _olderPageSettled() async {
    final key = feedKey(
      widget.conversationId,
      threadRootId: widget.threadRootId,
    );
    final settled = Completer<void>();
    final sub = ref.listenManual<bool>(
      chatProvider.select((s) => s.feeds[key]?.loadingMore ?? false),
      (_, loading) {
        if (!loading && !settled.isCompleted) settled.complete();
      },
      fireImmediately: true,
    );
    try {
      await settled.future.timeout(const Duration(seconds: 20));
    } on TimeoutException {
      // A page that never lands ends the walk like the end of history.
    } finally {
      sub.close();
    }
  }

  Widget jumpScope({required Widget child}) =>
      TimelineJumpScope(controller: jumpController, child: child);

  void disposeJump() {
    _jump?.dispose();
    _jump = null;
  }
}

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/chat_provider.dart';
import 'chat_timeline.dart';

/// When the timeline asks for the page before the oldest message shown.
///
/// It used to ask 120 pixels from the top — two rows away, so the reader was
/// always standing at the edge when the load began and watched it happen.
/// Signal keeps three pages loaded either side of what is on screen; this
/// keeps [_leadViewports] screens of history above the reader, so a page is
/// read, opened and laid out before anyone can scroll to where it goes.
mixin ChatTimelineOlder on ConsumerState<ChatTimeline> {
  ScrollController get timelineScrollController;

  /// Screens of history kept loaded beyond the top of the viewport. A thread
  /// keeps the old short lead: its replies page the other way, a whole
  /// thread at a time, and nothing there waited on scrolling.
  static const _leadViewports = 3.0;
  static const _threadLeadPixels = 120.0;

  /// The reader has moved the list in this conversation. Until then nothing
  /// is loaded ahead: most chats are opened, read at the bottom and closed.
  bool _scrolled = false;

  /// Message count the last unprompted load was started at, so a load that
  /// adds nothing cannot ask again in a loop.
  int _filledAt = -1;

  void resetOlderLoading() {
    _scrolled = false;
    _filledAt = -1;
  }

  /// Called on every scroll movement.
  void loadOlderIfNear() {
    final scroll = timelineScrollController;
    if (!scroll.hasClients) return;
    final position = scroll.position;
    if (position.pixels > 0) _scrolled = true;
    final lead = widget.threadRootId == null
        ? position.viewportDimension * _leadViewports
        : _threadLeadPixels;
    if (position.extentAfter > lead) return;
    ref
        .read(chatProvider.notifier)
        .loadMoreFeed(widget.conversationId, threadRootId: widget.threadRootId);
  }

  /// Called from build. Scroll movement is the only other trigger, and it
  /// never comes in two cases: a page landed while the list was at rest and
  /// the lead is still short, or the loaded messages do not fill the screen
  /// at all, so there is nothing to scroll.
  void keepOlderLead(ChatFeed feed) {
    if (widget.threadRootId != null) return;
    if (!feed.hasMore || feed.loading || feed.loadingMore) return;
    if (feed.messages.isEmpty || feed.messages.length == _filledAt) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final scroll = timelineScrollController;
      if (!mounted || !scroll.hasClients) return;
      if (!_scrolled && scroll.position.maxScrollExtent > 0) return;
      _filledAt = feed.messages.length;
      loadOlderIfNear();
    });
  }
}

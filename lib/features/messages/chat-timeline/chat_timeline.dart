import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/chat_provider.dart';
import 'chat_timeline_jump.dart';
import 'chat_timeline_load.dart';
import 'chat_timeline_selection.dart';
import 'chat_timeline_unread.dart';
import 'chat_timeline_view.dart';
import 'timeline_reveal_policy.dart';

class ChatTimeline extends ConsumerStatefulWidget {
  const ChatTimeline({
    super.key,
    required this.conversationId,
    this.threadRootId,
    this.header,
    this.leading,
  });

  final String conversationId;
  final String? threadRootId;

  /// Top bar that auto-hides while scrolling message history (Wall-style).
  final Widget? header;

  /// Scrolls as the oldest row of the list (a thread's root message).
  final Widget? leading;

  @override
  ConsumerState<ChatTimeline> createState() => _ChatTimelineState();
}

class _ChatTimelineState extends ConsumerState<ChatTimeline>
    with
        ChatTimelineLoad,
        ChatTimelineUnread,
        ChatTimelineJump,
        ChatTimelineSelection {
  final _scrollCtrl = ScrollController();

  @override
  ScrollController get timelineScrollController => _scrollCtrl;
  bool _headerVisible = true;
  bool _showJumpPill = false;
  double _lastPixels = 0;
  String? _previousNewestMessageId;

  // Auto-scroll when new messages arrive if user is within this many pixels
  // of the bottom (pixel 0 in a reverse: true list).
  static const _autoScrollThreshold = 200.0;

  /// How far up the history the jump-to-bottom button waits for.
  static const _jumpPillThreshold = 400.0;

  @override
  void initState() {
    super.initState();
    resetUnreadAnchor();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      loadFeed();
    });
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(covariant ChatTimeline oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.conversationId != widget.conversationId ||
        oldWidget.threadRootId != widget.threadRootId) {
      _previousNewestMessageId = null;
      resetUnreadAnchor();
      loadFeed();
      if (!_headerVisible) setState(() => _headerVisible = true);
      _lastPixels = 0;
    }
  }

  /// Scroll to the bottom (newest message) in a reverse:true list.
  void _scrollToBottom() {
    if (!_scrollCtrl.hasClients) return;
    _scrollCtrl.jumpTo(0);
  }

  void _jumpToBottom() {
    _scrollToBottom();
    clearUnreadPill();
  }

  void _revealSubmittedMessage() {
    clearUnreadAnchor();
    // The pending bubble is inserted asynchronously. Reveal once after that
    // state update and once more after any IME/composer layout settles.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    });
  }

  bool get _isNearBottom {
    if (!_scrollCtrl.hasClients) return true;
    return _scrollCtrl.position.pixels <= _autoScrollThreshold;
  }

  void _onScroll() {
    if (!_scrollCtrl.hasClients) return;
    final pos = _scrollCtrl.position;
    final pixels = pos.pixels;

    final wantPill = pixels > _jumpPillThreshold;
    if (wantPill != _showJumpPill) setState(() => _showJumpPill = wantPill);

    if (pixels >= pos.maxScrollExtent - 120) {
      ref
          .read(chatProvider.notifier)
          .loadMoreFeed(
            widget.conversationId,
            threadRootId: widget.threadRootId,
          );
    }

    if (widget.header == null) {
      _lastPixels = pixels;
      return;
    }

    final delta = pixels - _lastPixels;
    _lastPixels = pixels;
    final wantHeader = resolveHeaderVisibility(
      pixels: pixels,
      delta: delta,
      visible: _headerVisible,
    );
    if (wantHeader != _headerVisible) {
      setState(() => _headerVisible = wantHeader);
    }
  }

  @override
  void dispose() {
    disposeJump();
    _scrollCtrl.dispose();
    super.dispose();
  }

  ChatFeed _feedOf(ChatState chat) =>
      chat.feedFor(widget.conversationId, threadRootId: widget.threadRootId);

  @override
  Widget build(BuildContext context) {
    // Only this feed and "me": the whole state rebuilt every row mid-scroll.
    final feed = ref.watch(chatProvider.select(_feedOf));
    final userId = ref.watch(chatProvider.select((c) => c.currentUserId));

    pinUnreadAnchor(feed.messages);

    final newestMessageId = feed.messages.lastOrNull?.id;
    if (shouldRevealNewestMessage(
      previousNewestId: _previousNewestMessageId,
      messages: feed.messages,
      currentUserId: userId,
      isNearBottom: _isNearBottom,
    )) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }
    _previousNewestMessageId = newestMessageId;
    pruneSelection(feed.messages);

    return jumpScope(
      child: ChatTimelineView(
        conversationId: widget.conversationId,
        threadRootId: widget.threadRootId,
        header: widget.header,
        leading: widget.leading,
        headerVisible: _headerVisible,
        messages: feed.messages,
        loading: feed.loading,
        loadingMore: feed.loadingMore,
        currentUserId: userId,
        error: feed.error,
        scrollController: _scrollCtrl,
        unreadAnchorId: unreadAnchorId,
        unreadCount: unreadCount,
        unreadPillCount: unreadPillCount,
        showJumpPill: _showJumpPill,
        onJumpToBottom: _jumpToBottom,
        onRetry: loadFeed,
        onMessageSubmitted: _revealSubmittedMessage,
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/chat_provider.dart';
import 'composer.dart';
import 'message_list.dart';

class ChatTimeline extends ConsumerStatefulWidget {
  const ChatTimeline({
    super.key,
    required this.conversationId,
    this.threadRootId,
    this.header,
  });

  final String conversationId;
  final String? threadRootId;

  /// Top bar that auto-hides while scrolling message history (Wall-style).
  final Widget? header;

  @override
  ConsumerState<ChatTimeline> createState() => _ChatTimelineState();
}

class _ChatTimelineState extends ConsumerState<ChatTimeline> {
  final _scrollCtrl = ScrollController();
  bool _headerVisible = true;
  double _lastPixels = 0;
  int _prevMessageCount = 0;

  // Auto-scroll when new messages arrive if user is within this many pixels
  // of the bottom (pixel 0 in a reverse: true list).
  static const _autoScrollThreshold = 200.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(covariant ChatTimeline oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.conversationId != widget.conversationId ||
        oldWidget.threadRootId != widget.threadRootId) {
      _prevMessageCount = 0;
      _load();
      if (!_headerVisible) setState(() => _headerVisible = true);
      _lastPixels = 0;
    }
  }

  void _load() {
    final n = ref.read(chatProvider.notifier);
    // Cache-first: hydrate from SQLite immediately so messages show with 0
    // network latency. Then force a fresh network fetch in the background.
    // This is exactly how WhatsApp loads conversations.
    n.hydrateFeedFromCache(widget.conversationId).then((_) {
      n.loadFeed(
        widget.conversationId,
        threadRootId: widget.threadRootId,
        force: true,
      );
    });
    if (widget.threadRootId == null) {
      n.markConversationRead(widget.conversationId);
    }
  }

  /// Scroll to the bottom (newest message) in a reverse:true list.
  void _scrollToBottom() {
    if (!_scrollCtrl.hasClients) return;
    _scrollCtrl.animateTo(
      0,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  bool get _isNearBottom {
    if (!_scrollCtrl.hasClients) return true;
    return _scrollCtrl.position.pixels <= _autoScrollThreshold;
  }

  void _onScroll() {
    if (!_scrollCtrl.hasClients) return;
    final pos = _scrollCtrl.position;
    final pixels = pos.pixels;

    if (pixels >= pos.maxScrollExtent - 120) {
      ref.read(chatProvider.notifier).loadMoreFeed(
            widget.conversationId,
            threadRootId: widget.threadRootId,
          );
    }

    if (widget.header == null) {
      _lastPixels = pixels;
      return;
    }

    // reverse:true list — scrolling into older history increases [pixels].
    final delta = pixels - _lastPixels;
    _lastPixels = pixels;

    if (pixels < 24) {
      if (!_headerVisible) setState(() => _headerVisible = true);
      return;
    }
    if (delta.abs() < 8) return;
    if (delta > 0 && _headerVisible) {
      setState(() => _headerVisible = false);
    } else if (delta < 0 && !_headerVisible) {
      setState(() => _headerVisible = true);
    }
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chat = ref.watch(chatProvider);
    final feed = chat.feedFor(
      widget.conversationId,
      threadRootId: widget.threadRootId,
    );

    // Auto-scroll to bottom when a new message arrives and user is near bottom.
    final currentCount = feed.messages.length;
    if (currentCount > _prevMessageCount && _prevMessageCount > 0) {
      if (_isNearBottom) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      }
    }
    _prevMessageCount = currentCount;

    return Column(
      children: [
        if (widget.header != null)
          ClipRect(
            child: AnimatedAlign(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              heightFactor: _headerVisible ? 1 : 0,
              child: widget.header,
            ),
          ),
        Expanded(
          child: MessageList(
            messages: feed.messages,
            loading: feed.loading,
            loadingMore: feed.loadingMore,
            currentUserId: chat.currentUserId,
            scrollController: _scrollCtrl,
            conversationId: widget.conversationId,
            threadRootId: widget.threadRootId,
          ),
        ),
        MessageComposer(
          conversationId: widget.conversationId,
          parentId: widget.threadRootId,
          hintName: chat
                  .conversationById(widget.conversationId)
                  ?.displayTitle(chat.currentUserId) ??
              'someone',
          isGroup: chat.conversationById(widget.conversationId)?.isChannel ??
              false,
        ),
      ],
    );
  }
}

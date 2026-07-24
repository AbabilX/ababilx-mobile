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
  });

  final String conversationId;
  final String? threadRootId;

  @override
  ConsumerState<ChatTimeline> createState() => _ChatTimelineState();
}

class _ChatTimelineState extends ConsumerState<ChatTimeline> {
  final _scrollCtrl = ScrollController();

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
      _load();
    }
  }

  void _load() {
    final n = ref.read(chatProvider.notifier);
    n.loadFeed(widget.conversationId, threadRootId: widget.threadRootId);
    if (widget.threadRootId == null) {
      n.markConversationRead(widget.conversationId);
    }
  }

  void _onScroll() {
    if (!_scrollCtrl.hasClients) return;
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 120) {
      ref.read(chatProvider.notifier).loadMoreFeed(
            widget.conversationId,
            threadRootId: widget.threadRootId,
          );
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
    return Column(
      children: [
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
        ),
      ],
    );
  }
}

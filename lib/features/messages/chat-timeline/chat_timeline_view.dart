import 'package:flutter/material.dart';

import '../data/models/chat_models.dart';
import '../safety_number/safety_number_banner.dart';
import 'message_list.dart';
import 'scroll_to_bottom_pill.dart';
import 'timeline_composer.dart';

/// The chat's layout: collapsing header, message list with the jump-to-bottom
/// button floating over it, composer underneath. All state lives in
/// [ChatTimeline]; this only arranges it.
class ChatTimelineView extends StatelessWidget {
  const ChatTimelineView({
    super.key,
    required this.conversationId,
    required this.threadRootId,
    required this.header,
    required this.headerVisible,
    required this.messages,
    required this.loading,
    required this.loadingMore,
    required this.currentUserId,
    required this.error,
    required this.scrollController,
    required this.unreadAnchorId,
    required this.unreadCount,
    required this.unreadPillCount,
    required this.showJumpPill,
    required this.onJumpToBottom,
    required this.onRetry,
    required this.onMessageSubmitted,
  });

  final String conversationId;
  final String? threadRootId;
  final Widget? header;
  final bool headerVisible;
  final List<ChatMessage> messages;
  final bool loading;
  final bool loadingMore;
  final String currentUserId;
  final String error;
  final ScrollController scrollController;
  final String? unreadAnchorId;
  final int unreadCount;
  final int unreadPillCount;
  final bool showJumpPill;
  final VoidCallback onJumpToBottom;
  final VoidCallback onRetry;
  final VoidCallback onMessageSubmitted;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (header != null)
          ClipRect(
            child: AnimatedAlign(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              heightFactor: headerVisible ? 1 : 0,
              child: header,
            ),
          ),
        Expanded(
          child: Padding(
            // The header carries its own top safe-area padding, so it's fine
            // while visible — but auto-hide collapses it to zero height along
            // with everything else, and the list underneath was drawing right
            // under the status bar/notch the moment that happened. Only add
            // this back while the header is actually gone.
            padding: EdgeInsets.only(
              top: headerVisible ? 0 : MediaQuery.paddingOf(context).top,
            ),
            child: Stack(
              children: [
                MessageList(
                  messages: messages,
                  loading: loading,
                  loadingMore: loadingMore,
                  currentUserId: currentUserId,
                  scrollController: scrollController,
                  conversationId: conversationId,
                  threadRootId: threadRootId,
                  error: error,
                  onRetry: onRetry,
                  unreadAnchorId: unreadAnchorId,
                  unreadCount: unreadCount,
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: ScrollToBottomPill(
                    visible: showJumpPill,
                    unreadCount: unreadPillCount,
                    onTap: onJumpToBottom,
                  ),
                ),
              ],
            ),
          ),
        ),
        // Renders only when the peer's identity key has changed under us. It
        // sits above the composer, not in the collapsing header, because a
        // warning that scrolls away is a warning nobody reads.
        SafetyNumberBanner(conversationId: conversationId),
        TimelineComposer(
          conversationId: conversationId,
          parentId: threadRootId,
          onMessageSubmitted: onMessageSubmitted,
        ),
      ],
    );
  }
}

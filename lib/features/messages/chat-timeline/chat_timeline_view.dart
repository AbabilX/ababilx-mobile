import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../chat-select/message_selection.dart';
import '../chat-select/selection_bar.dart';
import '../chat-select/selection_top_bar.dart';
import '../data/models/chat_models.dart';
import '../safety_number/safety_number_banner.dart';
import 'message_list.dart';
import 'pinned_message_banner.dart';
import 'scroll_to_bottom_pill.dart';
import 'timeline_composer.dart';

/// The chat's layout: collapsing header, message list with the jump-to-bottom
/// button floating over it, composer underneath. All state lives in
/// [ChatTimeline]; this only arranges it.
class ChatTimelineView extends ConsumerWidget {
  const ChatTimelineView({
    super.key,
    required this.conversationId,
    required this.threadRootId,
    required this.header,
    this.leading,
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
  final Widget? leading;
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
  Widget build(BuildContext context, WidgetRef ref) {
    final selection = ref.watch(messageSelectionProvider);
    // A thread panel has no header and no room for the two bars, so selection
    // is a main-timeline mode only — see the menu's `showSelect`.
    final selecting =
        threadRootId == null && selection.isActiveIn(conversationId);
    final selectedCount = selection.ids.length;
    // The header auto-hides on scroll; the selection bar must not, or the only
    // way out of the mode scrolls off the top.
    final showHeader = headerVisible || selecting;

    return Column(
      children: [
        if (selecting)
          SelectionTopBar(
            count: selectedCount,
            onClose: () => ref.read(messageSelectionProvider.notifier).clear(),
          )
        else if (header != null)
          ClipRect(
            child: AnimatedAlign(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              heightFactor: showHeader ? 1 : 0,
              child: header,
            ),
          ),
        if (threadRootId == null && !selecting)
          PinnedMessageBanner(
            conversationId: conversationId,
            messages: messages,
          ),
        // Keyed because the first and last children swap type when selection
        // starts or ends. With both ends changed, the Column can only match
        // the middle children by key. Unkeyed, it rebuilt the list from
        // scratch with a new ScrollPosition at 0, which threw the reader to
        // the newest message on every Select and every exit.
        Expanded(
          key: const ValueKey('timeline-body'),
          child: Padding(
            // The header carries its own top safe-area padding, so it's fine
            // while visible — but auto-hide collapses it to zero height along
            // with everything else, and the list underneath was drawing right
            // under the status bar/notch the moment that happened. Only add
            // this back while the header is actually gone.
            padding: EdgeInsets.only(
              top: showHeader ? 0 : MediaQuery.paddingOf(context).top,
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
                  leading: leading,
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
        SafetyNumberBanner(
          key: const ValueKey('timeline-safety-banner'),
          conversationId: conversationId,
        ),
        if (selecting)
          SelectionBar(conversationId: conversationId)
        else
          TimelineComposer(
            conversationId: conversationId,
            parentId: threadRootId,
            onMessageSubmitted: onMessageSubmitted,
          ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_translations.dart';
import '../data/models/chat_models.dart';
import '../providers/chat_provider.dart';
import 'message_list.dart';
import 'quote_chain.dart';
import 'sheet_pull_to_close.dart';

/// Signal's `MessageQuotesBottomSheet`: the message and everything that
/// replies to it, read in one place instead of hunted for down the timeline.
/// It is a reading surface — no composer; replying is done from a row's own
/// menu or swipe, back in the chat.
void showQuoteRepliesSheet(
  BuildContext context,
  ChatMessage message, {
  String? threadRootId,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => SafeArea(
      top: false,
      child: FractionallySizedBox(
        heightFactor: 0.7,
        child: SheetPullToClose(
          child: _QuoteReplies(message: message, threadRootId: threadRootId),
        ),
      ),
    ),
  );
}

class _QuoteReplies extends ConsumerStatefulWidget {
  const _QuoteReplies({required this.message, required this.threadRootId});

  final ChatMessage message;
  final String? threadRootId;

  @override
  ConsumerState<_QuoteReplies> createState() => _QuoteRepliesState();
}

class _QuoteRepliesState extends ConsumerState<_QuoteReplies> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final message = widget.message;
    final threadRootId = widget.threadRootId;
    final conversationId = message.conversationId;
    final messages = ref.watch(
      chatProvider.select(
        (c) => c.feedFor(conversationId, threadRootId: threadRootId).messages,
      ),
    );
    final userId = ref.watch(chatProvider.select((c) => c.currentUserId));
    final chain = quoteChain(messages, message.id);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            AppTranslations.translate(context, ref, 'chat_replies'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        Expanded(
          child: MessageList(
            messages: chain,
            loading: false,
            loadingMore: false,
            currentUserId: userId,
            scrollController: _scroll,
            conversationId: conversationId,
            threadRootId: threadRootId,
            indicators: false,
          ),
        ),
      ],
    );
  }
}

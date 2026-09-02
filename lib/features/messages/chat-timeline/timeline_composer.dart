import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/chat_provider.dart';
import 'composer.dart';
import 'composer_locked.dart';
import 'message_request_bar.dart';

class TimelineComposer extends ConsumerWidget {
  const TimelineComposer({
    super.key,
    required this.conversationId,
    this.parentId,
    this.onMessageSubmitted,
  });

  final String conversationId;
  final String? parentId;
  final VoidCallback? onMessageSubmitted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chat = ref.watch(chatProvider);
    final conversation = chat.conversationById(conversationId);
    if (conversation?.canMessage == false) return const ComposerLocked();
    if (conversation?.isIncomingRequest == true) {
      return MessageRequestBar(conversation: conversation!);
    }
    return MessageComposer(
      conversationId: conversationId,
      parentId: parentId,
      hintName: conversation?.displayTitle(chat.currentUserId) ?? 'someone',
      isGroup: conversation?.isGroupConversation ?? false,
      onMessageSubmitted: onMessageSubmitted,
    );
  }
}

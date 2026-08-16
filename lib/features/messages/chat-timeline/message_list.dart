import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../chat-date-divider/index.dart';
import '../chat_utils.dart';
import '../data/models/chat_models.dart';
import 'message_row.dart';
import 'thread_sheet.dart';
import 'group_call_event_row.dart';
import 'voice_call_event_row.dart';

class MessageList extends ConsumerWidget {
  const MessageList({
    super.key,
    required this.messages,
    required this.loading,
    required this.loadingMore,
    required this.currentUserId,
    required this.scrollController,
    required this.conversationId,
    this.threadRootId,
  });

  final List<ChatMessage> messages;
  final bool loading;
  final bool loadingMore;
  final String currentUserId;
  final ScrollController scrollController;
  final String conversationId;
  final String? threadRootId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (loading && messages.isEmpty) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2.5));
    }
    return ListView.builder(
      controller: scrollController,
      reverse: true,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      itemCount: messages.length + (loadingMore ? 1 : 0),
      itemBuilder: (_, i) {
        if (loadingMore && i == messages.length) {
          return const Padding(
            padding: EdgeInsets.all(12),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        final idx = messages.length - 1 - i;
        final msg = messages[idx];
        final prev = idx > 0 ? messages[idx - 1] : null;
        final showDate =
            prev == null || !isSameDay(prev.createdAt, msg.createdAt);
        return Column(
          children: [
            if (showDate)
              ChatDateDivider(label: formatDateDivider(msg.createdAt)),
            if (msg.isVoiceCall)
              VoiceCallEventRow(message: msg, currentUserId: currentUserId)
            else if (msg.isGroupCall)
              GroupCallEventRow(message: msg)
            else
              MessageRow(
                message: msg,
                conversationId: conversationId,
                threadRootId: threadRootId,
                onOpenThread: threadRootId == null && msg.threadCount > 0
                    ? () => openThreadSheet(context, conversationId, msg)
                    : null,
              ),
          ],
        );
      },
    );
  }
}

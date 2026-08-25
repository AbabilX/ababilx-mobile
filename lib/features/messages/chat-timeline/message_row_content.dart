import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/app_avatar.dart';
import '../chat_utils.dart';
import '../data/models/chat_models.dart';
import '../providers/chat_provider.dart';
import 'message_body.dart';
import 'message_delivery_status.dart';
import 'quick_react_sheet.dart';
import 'reaction_row.dart';
import 'thread_summary.dart';
import 'user_profile_sheet.dart';

class MessageRowContent extends ConsumerWidget {
  const MessageRowContent({
    super.key,
    required this.message,
    required this.pulse,
    required this.isSending,
    required this.isFailed,
    required this.actionsOpen,
    this.onOpenThread,
  });

  final ChatMessage message;
  final Animation<double> pulse;
  final bool isSending;
  final bool isFailed;
  final bool actionsOpen;
  final VoidCallback? onOpenThread;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final name = message.userName ?? 'Unknown';
    final notifier = ref.read(chatProvider.notifier);
    final replies = ref.watch(chatProvider).threadRepliesByRoot[message.id];

    void showProfile() => showUserProfileSheet(
      context: context,
      ref: ref,
      userId: message.userId,
      userName: name,
      userAvatarUrl: message.userAvatarUrl,
    );

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: isSending ? 0.65 : 1,
      child: Container(
        decoration: actionsOpen
            ? BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(12),
              )
            : isFailed
            ? BoxDecoration(
                color: colors.errorContainer.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              )
            : null,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: showProfile,
              child: AppAvatar(
                size: 36,
                url: message.userAvatarUrl,
                name: name,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: GestureDetector(
                          onTap: showProfile,
                          child: Text(
                            name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      MessageDeliveryStatus(
                        status: message.sendStatus,
                        pulse: pulse,
                      ),
                      const SizedBox(width: 4),
                      if (!isSending)
                        Text(
                          isFailed
                              ? 'Tap to retry'
                              : formatChatTime(message.createdAt),
                          style: TextStyle(
                            fontSize: 12,
                            color: isFailed
                                ? colors.error
                                : colors.onSurfaceVariant,
                            fontWeight: isFailed
                                ? FontWeight.w500
                                : FontWeight.normal,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  MessageBody(message: message),
                  if (!message.isDeleted && message.reactions.isNotEmpty)
                    ReactionRow(
                      reactions: message.reactions,
                      onToggle: (emoji) =>
                          notifier.toggleReaction(message.id, emoji),
                      onAdd: () async {
                        final emoji = await showQuickReactSheet(context);
                        if (emoji != null) {
                          await notifier.toggleReaction(message.id, emoji);
                        }
                      },
                    ),
                  if (onOpenThread != null)
                    ThreadSummary(
                      root: message,
                      replies: replies ?? const [],
                      count: message.threadCount,
                      onTap: onOpenThread!,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

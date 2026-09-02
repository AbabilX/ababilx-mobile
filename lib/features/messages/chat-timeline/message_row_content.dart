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
    required this.isOwnMessage,
    required this.actionsOpen,
    this.clusterPosition = MessageClusterPosition.single,
    this.onOpenThread,
  });

  final ChatMessage message;
  final Animation<double> pulse;
  final bool isSending;
  final bool isFailed;
  final bool isOwnMessage;
  final bool actionsOpen;
  final MessageClusterPosition clusterPosition;
  final VoidCallback? onOpenThread;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final name = message.userName ?? 'Unknown';
    final notifier = ref.read(chatProvider.notifier);
    final replies = ref.watch(chatProvider).threadRepliesByRoot[message.id];
    final startsCluster =
        clusterPosition == MessageClusterPosition.single ||
        clusterPosition == MessageClusterPosition.start;
    final endsCluster =
        clusterPosition == MessageClusterPosition.single ||
        clusterPosition == MessageClusterPosition.end;
    final showFooter = endsCluster || isSending || isFailed;

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
        padding: EdgeInsets.fromLTRB(
          4,
          startsCluster ? 8 : 1,
          4,
          endsCluster ? 8 : 1,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (endsCluster)
              GestureDetector(
                onTap: showProfile,
                child: AppAvatar(
                  size: 36,
                  url: message.userAvatarUrl,
                  name: name,
                ),
              )
            else
              const SizedBox(width: 36),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (startsCluster) ...[
                    GestureDetector(
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
                    const SizedBox(height: 3),
                  ],
                  MessageBody(message: message),
                  if (showFooter)
                    Align(
                      alignment: isOwnMessage
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
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
                            if (isOwnMessage) ...[
                              const SizedBox(width: 4),
                              MessageDeliveryStatus(
                                status: message.sendStatus,
                                pulse: pulse,
                                delivery: message.delivery,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
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

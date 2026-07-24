import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../chat_utils.dart';
import '../data/models/chat_models.dart';
import '../providers/chat_provider.dart';
import 'message_actions.dart';
import 'message_body.dart';
import 'quick_react_sheet.dart';
import 'reaction_row.dart';
import 'thread_summary.dart';

class MessageRow extends ConsumerWidget {
  const MessageRow({
    super.key,
    required this.message,
    required this.conversationId,
    this.threadRootId,
    this.onOpenThread,
  });

  final ChatMessage message;
  final String conversationId;
  final String? threadRootId;
  final VoidCallback? onOpenThread;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final name = message.userName ?? 'Unknown';
    final n = ref.read(chatProvider.notifier);

    return InkWell(
      onLongPress: () => showMessageActions(
        context,
        ref,
        message,
        conversationId: conversationId,
        threadRootId: threadRootId,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SquareAvatar(name: name, url: message.userAvatarUrl),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        formatChatTime(message.createdAt),
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  MessageBody(message: message),
                  if (!message.isDeleted && message.reactions.isNotEmpty)
                    ReactionRow(
                      reactions: message.reactions,
                      onToggle: (emoji) => n.toggleReaction(message.id, emoji),
                      onAdd: () async {
                        final emoji = await showQuickReactSheet(context);
                        if (emoji != null) {
                          await n.toggleReaction(message.id, emoji);
                        }
                      },
                    ),
                  if (onOpenThread != null)
                    ThreadSummary(
                      root: message,
                      replies: ref
                              .watch(chatProvider)
                              .threadRepliesByRoot[message.id] ??
                          const [],
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

class _SquareAvatar extends StatelessWidget {
  const _SquareAvatar({required this.name, this.url});
  final String name;
  final String? url;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 36,
        height: 36,
        child: url != null
            ? CachedNetworkImage(imageUrl: url!, fit: BoxFit.cover)
            : ColoredBox(
                color: colors.surfaceContainerHighest,
                child: Center(
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: colors.onSurface,
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

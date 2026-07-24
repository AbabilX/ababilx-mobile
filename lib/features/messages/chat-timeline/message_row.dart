import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../chat_utils.dart';
import '../data/models/chat_models.dart';
import 'message_body.dart';
import 'reaction_row.dart';
import 'thread_summary.dart';

class MessageRow extends StatelessWidget {
  const MessageRow({
    super.key,
    required this.message,
    required this.onLongPress,
    this.onOpenThread,
  });

  final ChatMessage message;
  final VoidCallback onLongPress;
  final VoidCallback? onOpenThread;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final name = message.userName ?? 'Unknown';
    return GestureDetector(
      onLongPress: onLongPress,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 18,
              backgroundImage: message.userAvatarUrl != null
                  ? CachedNetworkImageProvider(message.userAvatarUrl!)
                  : null,
              child: message.userAvatarUrl == null
                  ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?')
                  : null,
            ),
            const SizedBox(width: 10),
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
                            fontSize: 14,
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
                      if (message.editedAt != null) ...[
                        const SizedBox(width: 4),
                        Text(
                          'edited',
                          style: TextStyle(
                            fontSize: 11,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  MessageBody(message: message),
                  if (message.reactions.isNotEmpty)
                    ReactionRow(reactions: message.reactions),
                  if (onOpenThread != null)
                    ThreadSummary(
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

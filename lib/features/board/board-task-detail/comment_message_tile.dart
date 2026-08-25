import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../messages/tiptap_viewer.dart';
import '../data/models/board_models.dart';

class CommentMessageTile extends StatelessWidget {
  const CommentMessageTile({
    super.key,
    required this.comment,
    this.isReply = false,
    this.onDoubleTap,
    this.onTap,
  });

  final KanbanTaskComment comment;
  final bool isReply;
  final VoidCallback? onDoubleTap;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final name = comment.userName ?? 'Member';

    final content = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: colors.primaryContainer,
          backgroundImage: (comment.userAvatarUrl ?? '').isNotEmpty
              ? CachedNetworkImageProvider(comment.userAvatarUrl!)
              : null,
          child: (comment.userAvatarUrl ?? '').isEmpty
              ? Text(
                  name.characters.first.toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                )
              : null,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      name,
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    timeago.format(DateTime.parse(comment.createdAt)),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              TiptapViewer(content: comment.body),
            ],
          ),
        ),
      ],
    );

    final child = isReply
        ? Container(
            margin: const EdgeInsets.only(left: 12, bottom: 12),
            padding: const EdgeInsets.only(left: 12),
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: colors.outlineVariant.withValues(alpha: 0.8),
                  width: 2,
                ),
              ),
            ),
            child: content,
          )
        : Padding(padding: const EdgeInsets.only(bottom: 8), child: content);

    return GestureDetector(
      onTap: onTap,
      onDoubleTap: onDoubleTap,
      behavior: HitTestBehavior.opaque,
      child: child,
    );
  }
}

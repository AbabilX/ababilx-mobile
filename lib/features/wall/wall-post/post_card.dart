import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/wall_models.dart';
import '../providers/wall_provider.dart';
import '../wall_utils.dart';
import 'attachment_grid.dart';
import 'post_actions.dart';
import 'post_header.dart';
import 'reaction_chips.dart';

class WallPostCard extends ConsumerWidget {
  const WallPostCard({
    super.key,
    required this.post,
    this.onOpen,
    this.onComment,
    this.expanded = false,
  });

  final WallPost post;
  final VoidCallback? onOpen;
  final VoidCallback? onComment;
  final bool expanded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final body = wallBodyPlain(post.body);
    final me = ref.watch(wallProvider).currentUserId;

    return Material(
      color: scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: onOpen,
              borderRadius: BorderRadius.circular(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  WallPostHeader(post: post, isOwner: post.userId == me),
                  const SizedBox(height: 10),
                  Text(
                    body.isEmpty ? '(empty post)' : body,
                    maxLines: expanded ? null : 8,
                    overflow:
                        expanded ? TextOverflow.visible : TextOverflow.ellipsis,
                    style: TextStyle(
                      color: scheme.onSurface,
                      height: 1.35,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
            if (post.attachments.isNotEmpty) ...[
              const SizedBox(height: 10),
              WallAttachmentGrid(attachments: post.attachments),
            ],
            if (post.reactions.isNotEmpty) ...[
              const SizedBox(height: 10),
              WallReactionChips(
                reactions: post.reactions,
                onTap: (emoji) =>
                    ref.read(wallProvider.notifier).react(post.id, emoji),
              ),
            ],
            const SizedBox(height: 8),
            WallPostActions(
              post: post,
              showComment: !expanded,
              onComment: onComment,
            ),
          ],
        ),
      ),
    );
  }
}

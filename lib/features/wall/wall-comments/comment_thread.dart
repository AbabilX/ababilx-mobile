import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/app_avatar.dart';
import '../data/models/wall_models.dart';
import '../providers/wall_provider.dart';
import '../wall_utils.dart';

class WallCommentThread extends ConsumerWidget {
  const WallCommentThread({
    super.key,
    required this.post,
    required this.onReply,
  });

  final WallPost post;
  final ValueChanged<WallComment> onReply;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roots = post.comments.where((c) => c.parentId == null).toList();
    final replies = <String, List<WallComment>>{};
    for (final c in post.comments) {
      final p = c.parentId;
      if (p == null) continue;
      replies.putIfAbsent(p, () => []).add(c);
    }

    if (roots.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Text(
          'No comments yet',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return Column(
      children: [
        for (final root in roots) ...[
          _CommentTile(
            comment: root,
            postId: post.id,
            onReply: () => onReply(root),
          ),
          for (final r in replies[root.id] ?? const <WallComment>[])
            Padding(
              padding: const EdgeInsets.only(left: 36),
              child: _CommentTile(
                comment: r,
                postId: post.id,
                onReply: () => onReply(r),
              ),
            ),
        ],
      ],
    );
  }
}

class _CommentTile extends ConsumerWidget {
  const _CommentTile({
    required this.comment,
    required this.postId,
    required this.onReply,
  });

  final WallComment comment;
  final String postId;
  final VoidCallback onReply;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final me = ref.watch(wallProvider).currentUserId;
    final plain = wallBodyPlain(comment.body);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppAvatar(
            name: comment.userName ?? '?',
            url: comment.userAvatarUrl,
            size: 28,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  comment.userName ?? 'Member',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(plain, style: TextStyle(color: scheme.onSurface)),
                Row(
                  children: [
                    Text(
                      wallRelativeTime(comment.createdAt),
                      style: TextStyle(
                        fontSize: 11,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    if (comment.userId == me)
                      TextButton(
                        onPressed: () => ref
                            .read(wallProvider.notifier)
                            .deleteComment(postId, comment.id),
                        child: const Text('Delete'),
                      ),
                    TextButton(
                      onPressed: onReply,
                      child: const Text('Reply'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

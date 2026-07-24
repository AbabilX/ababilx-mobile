import 'package:flutter/material.dart';

import '../data/models/wall_models.dart';
import 'thread_block.dart';

class WallCommentThread extends StatelessWidget {
  const WallCommentThread({
    super.key,
    required this.post,
    required this.onReply,
  });

  final WallPost post;
  final ValueChanged<WallComment> onReply;

  @override
  Widget build(BuildContext context) {
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
        for (final root in roots)
          WallCommentThreadBlock(
            root: root,
            replies: replies[root.id] ?? const <WallComment>[],
            postId: post.id,
            onReply: () => onReply(root),
          ),
      ],
    );
  }
}

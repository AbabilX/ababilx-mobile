import 'package:flutter/material.dart';

import '../data/models/wall_models.dart';
import 'comment_thread_screen.dart';
import 'comment_tile.dart';
import 'reply_summary.dart';

/// One root comment + a reply-count summary that opens a dedicated thread
/// screen (DM-thread parity — no inline expand, no nested indent).
class WallCommentThreadBlock extends StatelessWidget {
  const WallCommentThreadBlock({
    super.key,
    required this.root,
    required this.replies,
    required this.postId,
    required this.onReply,
  });

  final WallComment root;
  final List<WallComment> replies;
  final String postId;
  final VoidCallback onReply;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        WallCommentTile(comment: root, postId: postId, onReply: onReply),
        if (replies.isNotEmpty)
          WallReplySummary(
            root: root,
            replies: replies,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) =>
                    WallCommentThreadScreen(postId: postId, rootId: root.id),
              ),
            ),
          ),
      ],
    );
  }
}

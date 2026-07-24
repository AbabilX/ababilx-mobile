import 'package:flutter/material.dart';

import '../data/models/wall_models.dart';
import 'comment_tile.dart';
import 'reply_summary.dart';

/// One root comment + collapsible reply thread (web WallCommentThread parity).
class WallCommentThreadBlock extends StatefulWidget {
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
  State<WallCommentThreadBlock> createState() => _WallCommentThreadBlockState();
}

class _WallCommentThreadBlockState extends State<WallCommentThreadBlock> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final root = widget.root;
    final replies = widget.replies;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        WallCommentTile(
          comment: root,
          postId: widget.postId,
          onReply: widget.onReply,
        ),
        if (replies.isNotEmpty)
          WallReplySummary(
            root: root,
            replies: replies,
            expanded: _expanded,
            onToggle: () => setState(() => _expanded = !_expanded),
          ),
        if (_expanded)
          for (final r in replies)
            WallCommentTile(
              comment: r,
              postId: widget.postId,
              isReply: true,
              replyToName: root.userName,
            ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../messages/chat_icon.dart';
import '../providers/wall_provider.dart';
import 'comment_composer.dart';
import 'comment_tile.dart';

/// Dedicated reply thread — root comment pinned at top, its replies below,
/// composer fixed to the bottom. Same navigation pattern as a DM thread
/// (separate pushed screen, not an inline expando).
class WallCommentThreadScreen extends ConsumerWidget {
  const WallCommentThreadScreen({
    super.key,
    required this.postId,
    required this.rootId,
  });

  final String postId;
  final String rootId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(wallPostProvider(postId));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const ChatIcon(HugeIcons.strokeRoundedArrowLeft01),
        ),
        title: const Text('Thread'),
      ),
      body: async.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
        error: (e, _) => Center(child: Text('Failed to load\n$e')),
        data: (post) {
          final rootIndex = post.comments.indexWhere((c) => c.id == rootId);
          if (rootIndex == -1) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (Navigator.of(context).canPop()) Navigator.of(context).pop();
            });
            return const SizedBox.shrink();
          }
          final root = post.comments[rootIndex];
          final replies = post.comments
              .where((c) => c.parentId == rootId)
              .toList();

          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  children: [
                    WallCommentTile(comment: root, postId: postId),
                    if (replies.isNotEmpty) ...[
                      const Divider(height: 20),
                      for (final reply in replies)
                        WallCommentTile(
                          comment: reply,
                          postId: postId,
                          isReply: true,
                          replyToName: root.userName,
                        ),
                    ],
                  ],
                ),
              ),
              WallCommentComposer(postId: postId, parentId: rootId),
            ],
          );
        },
      ),
    );
  }
}

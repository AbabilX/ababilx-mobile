import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/board_repository.dart';
import '../data/models/board_models.dart';
import '../providers/board_detail_provider.dart';
import 'comment_message_tile.dart';
import 'comment_threads.dart';
import 'kanban_comment_composer.dart';

void openCommentThread(
  BuildContext context, {
  required String boardId,
  required String taskId,
  required String commentId,
}) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => CommentThreadPage(
        boardId: boardId,
        taskId: taskId,
        anchorCommentId: commentId,
      ),
    ),
  );
}

class CommentThreadPage extends ConsumerWidget {
  const CommentThreadPage({
    super.key,
    required this.boardId,
    required this.taskId,
    required this.anchorCommentId,
  });

  final String boardId;
  final String taskId;
  final String anchorCommentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final taskAsync = ref.watch(kanbanTaskProvider(taskId));
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return taskAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: const Text('Thread')),
        body: Center(child: Text('Could not load thread\n$e')),
      ),
      data: (task) {
        final threads = buildCommentThreads(task.comments);
        late final KanbanTaskComment root;
        try {
          root = threads.threadRoot(anchorCommentId);
        } catch (_) {
          return Scaffold(
            appBar: AppBar(title: const Text('Thread')),
            body: const Center(child: Text('Comment not found')),
          );
        }
        final replies = threads.repliesFor(root.id);

        return Scaffold(
          appBar: AppBar(
            title: const Text('Thread'),
            leading: IconButton(
              icon: const Icon(Icons.close_rounded),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          body: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  children: [
                    CommentMessageTile(comment: root),
                    if (replies.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          'No replies yet. Be the first to reply.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      )
                    else
                      for (final reply in replies)
                        CommentMessageTile(comment: reply, isReply: true),
                  ],
                ),
              ),
              KanbanCommentComposer(
                taskId: task.id,
                hintName: 'thread',
                sendLabelKey: 'Reply',
                onSubmit: ({required bodyJson, required attachments}) async {
                  await ref
                      .read(boardRepositoryProvider)
                      .createComment(
                        task.id,
                        bodyJson,
                        parentId: root.id,
                        attachments: attachments,
                      );
                  ref.invalidate(kanbanTaskProvider(task.id));
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

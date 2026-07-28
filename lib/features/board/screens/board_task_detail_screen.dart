import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../board-task-detail/index.dart';

/// Full-screen Kanban task detail (outside shell).
class BoardTaskDetailScreen extends ConsumerWidget {
  const BoardTaskDetailScreen({
    super.key,
    required this.boardId,
    required this.taskId,
  });

  final String boardId;
  final String taskId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return BoardTaskDetailPage(boardId: boardId, taskId: taskId);
  }
}

void openBoardTask(
  BuildContext context, {
  required String boardId,
  required String taskId,
}) {
  context.push('/board/$boardId/tasks/$taskId');
}

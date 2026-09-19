import 'package:flutter/material.dart';
import 'package:ababilx/shared/widgets/app_bar_back_button.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../board-kanban/index.dart';
import '../providers/board_detail_provider.dart';

class BoardDetailScreen extends ConsumerWidget {
  const BoardDetailScreen({super.key, required this.boardId, this.taskId});

  final String boardId;
  final String? taskId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(boardDetailProvider(boardId));
    final title = state.board?.name ?? 'Board';

    return Scaffold(
      appBar: AppBar(
        leading: const AppBarBackButton(),
        title: Text(title),
        actions: [
          if (state.loading)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            IconButton(
              tooltip: 'Refresh',
              onPressed: () =>
                  ref.read(boardDetailProvider(boardId).notifier).refresh(),
              icon: const Icon(Icons.refresh_rounded),
            ),
        ],
      ),
      body: BoardKanbanView(boardId: boardId, initialTaskId: taskId),
    );
  }
}

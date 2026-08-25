import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/board_models.dart';
import '../providers/board_detail_provider.dart';
import '../screens/board_task_detail_screen.dart';
import '../shared/kanban_utils.dart';
import 'kanban_column.dart';

class BoardKanbanView extends ConsumerStatefulWidget {
  const BoardKanbanView({super.key, required this.boardId, this.initialTaskId});

  final String boardId;
  final String? initialTaskId;

  @override
  ConsumerState<BoardKanbanView> createState() => _BoardKanbanViewState();
}

class _BoardKanbanViewState extends ConsumerState<BoardKanbanView> {
  final _searchCtrl = TextEditingController();
  var _openedInitialTask = false;
  var _searchText = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _maybeOpenInitialTask() {
    if (_openedInitialTask || widget.initialTaskId == null) return;
    _openedInitialTask = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      openBoardTask(
        context,
        boardId: widget.boardId,
        taskId: widget.initialTaskId!,
      );
    });
  }

  void _openTask(KanbanTask task) {
    openBoardTask(context, boardId: widget.boardId, taskId: task.id);
  }

  Future<void> _createTask(String title) async {
    final task = await ref
        .read(boardDetailProvider(widget.boardId).notifier)
        .createTask(title);
    if (task != null && mounted) _openTask(task);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(boardDetailProvider(widget.boardId));
    final notifier = ref.read(boardDetailProvider(widget.boardId).notifier);
    _maybeOpenInitialTask();

    if (state.loading && state.board == null) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2.5));
    }

    if (state.error != null && state.board == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(state.error!),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: notifier.refresh,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (state.board == null) {
      return const Center(child: Text('Board not found'));
    }

    final todo = todoColumn(state.columns);
    final grouped = state.groupedTasks;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'Search tasks…',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchText.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _searchText = '');
                        notifier.setSearch('');
                      },
                    )
                  : null,
              isDense: true,
              filled: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            onSubmitted: notifier.setSearch,
            onChanged: (v) {
              setState(() => _searchText = v);
              if (v.isEmpty) notifier.setSearch('');
            },
          ),
        ),
        if (state.error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              state.error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: notifier.refresh,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 4, 4, 16),
              children: [
                for (final column in state.columns)
                  SizedBox(
                    height: MediaQuery.sizeOf(context).height - 220,
                    child: KanbanColumnView(
                      column: column,
                      tasks: grouped[column.key] ?? const [],
                      onOpenTask: _openTask,
                      onMoveTask: (task, status) =>
                          notifier.moveTask(task, status),
                      onCreateTask: todo?.key == column.key
                          ? _createTask
                          : null,
                      createDisabled: state.moving,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/board_repository.dart';
import '../data/models/board_models.dart';
import '../shared/kanban_utils.dart';

class BoardDetailState extends Equatable {
  const BoardDetailState({
    this.board,
    this.tasks = const [],
    this.loading = false,
    this.error,
    this.searchQuery = '',
    this.moving = false,
  });

  final KanbanBoard? board;
  final List<KanbanTask> tasks;
  final bool loading;
  final String? error;
  final String searchQuery;
  final bool moving;

  List<KanbanColumn> get columns =>
      resolveBoardColumns(board?.columns ?? const []);

  Map<String, List<KanbanTask>> get groupedTasks =>
      groupTasksByColumn(tasks, columns);

  BoardDetailState copyWith({
    KanbanBoard? board,
    List<KanbanTask>? tasks,
    bool? loading,
    String? error,
    String? searchQuery,
    bool? moving,
    bool clearError = false,
  }) {
    return BoardDetailState(
      board: board ?? this.board,
      tasks: tasks ?? this.tasks,
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
      searchQuery: searchQuery ?? this.searchQuery,
      moving: moving ?? this.moving,
    );
  }

  @override
  List<Object?> get props => [
    board,
    tasks,
    loading,
    error,
    searchQuery,
    moving,
  ];
}

class BoardDetailNotifier extends FamilyNotifier<BoardDetailState, String> {
  BoardRepository get _repo => ref.read(boardRepositoryProvider);

  @override
  BoardDetailState build(String boardId) {
    Future.microtask(() => load());
    return const BoardDetailState(loading: true);
  }

  Future<void> load({String? searchQuery}) async {
    final boardId = arg;
    state = state.copyWith(
      loading: true,
      clearError: true,
      searchQuery: searchQuery ?? state.searchQuery,
    );
    try {
      final board = await _repo.findBoard(boardId);
      if (board == null) {
        state = state.copyWith(loading: false, error: 'Board not found');
        return;
      }
      final tasks = await _repo.listTasks(
        boardId,
        query: state.searchQuery.trim().isEmpty
            ? null
            : state.searchQuery.trim(),
      );
      state = state.copyWith(
        board: board,
        tasks: tasks,
        loading: false,
        clearError: true,
      );
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  Future<void> refresh() => load();

  Future<void> setSearch(String query) => load(searchQuery: query);

  Future<KanbanTask?> createTask(String title) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty || state.board == null) return null;
    try {
      final task = await _repo.createTask(state.board!.id, trimmed);
      state = state.copyWith(tasks: [task, ...state.tasks]);
      return task;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return null;
    }
  }

  Future<bool> moveTask(
    KanbanTask task,
    String toStatus, {
    int? position,
  }) async {
    final targetPos = position ?? (state.groupedTasks[toStatus]?.length ?? 0);
    final previous = state.tasks;
    state = state.copyWith(moving: true, clearError: true);
    state = state.copyWith(
      tasks: _optimisticMove(previous, task, toStatus, targetPos),
    );
    try {
      final updated = await _repo.moveTask(
        task.id,
        status: toStatus,
        position: targetPos,
      );
      state = state.copyWith(
        tasks: previous.map((t) => t.id == updated.id ? updated : t).toList(),
        moving: false,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        tasks: previous,
        moving: false,
        error: e.toString(),
      );
      return false;
    }
  }

  Future<bool> patchTask(String taskId, Map<String, dynamic> body) async {
    try {
      final updated = await _repo.patchTask(taskId, body);
      state = state.copyWith(
        tasks: state.tasks
            .map((t) => t.id == updated.id ? updated : t)
            .toList(),
      );
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<bool> deleteTask(String taskId) async {
    final previous = state.tasks;
    state = state.copyWith(
      tasks: previous.where((t) => t.id != taskId).toList(),
    );
    try {
      await _repo.deleteTask(taskId);
      return true;
    } catch (e) {
      state = state.copyWith(tasks: previous, error: e.toString());
      return false;
    }
  }

  List<KanbanTask> _optimisticMove(
    List<KanbanTask> tasks,
    KanbanTask task,
    String toStatus,
    int position,
  ) {
    final without = tasks.where((t) => t.id != task.id).toList();
    final moved = task.copyWith(status: toStatus, position: position);
    final inColumn = without.where((t) => t.status == toStatus).toList()
      ..sort((a, b) => a.position.compareTo(b.position));
    final clamped = position.clamp(0, inColumn.length);
    inColumn.insert(clamped, moved);
    final reindexed = <KanbanTask>[];
    for (var i = 0; i < inColumn.length; i++) {
      reindexed.add(inColumn[i].copyWith(position: i));
    }
    final others = without.where((t) => t.status != toStatus);
    return [...others, ...reindexed];
  }
}

final boardDetailProvider =
    NotifierProvider.family<BoardDetailNotifier, BoardDetailState, String>(
      BoardDetailNotifier.new,
    );

final kanbanTaskProvider = FutureProvider.family<KanbanTaskDetail, String>((
  ref,
  taskId,
) {
  return ref.watch(boardRepositoryProvider).getTask(taskId);
});

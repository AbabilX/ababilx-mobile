import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/board_repository.dart';
import '../data/models/board_models.dart';

final kanbanBoardsProvider = FutureProvider<List<KanbanBoard>>((ref) {
  return ref.watch(boardRepositoryProvider).listBoards();
});

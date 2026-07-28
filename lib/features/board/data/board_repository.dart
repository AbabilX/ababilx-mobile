import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import 'models/board_models.dart';

class BoardRepository {
  const BoardRepository(this._client);
  final ApiClient _client;

  Future<List<KanbanBoard>> listBoards() async {
    final res = await _client.get(ApiConstants.kanbanBoards);
    final data = unwrapApiData<List<dynamic>>(res);
    return data
        .map((e) => KanbanBoard.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

final boardRepositoryProvider = Provider<BoardRepository>(
  (ref) => BoardRepository(ref.watch(apiClientProvider)),
);

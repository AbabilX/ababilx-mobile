import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import 'models/board_models.dart';

class BoardTasksApi {
  const BoardTasksApi(this._client);
  final ApiClient _client;

  Future<List<KanbanTask>> listTasks(
    String boardId, {
    String? query,
    String? assigneeId,
  }) async {
    final res = await _client.get(
      ApiConstants.kanbanBoardTasks(boardId),
      queryParameters: {
        if (query != null && query.isNotEmpty) 'q': query,
        if (assigneeId != null && assigneeId.isNotEmpty)
          'assignee_id': assigneeId,
      },
    );
    final data = unwrapApiData<List<dynamic>>(res);
    return data
        .map((e) => KanbanTask.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<KanbanTask> createTask(String boardId, String title) async {
    final res = await _client.post(
      ApiConstants.kanbanBoardTasks(boardId),
      data: {'title': title},
    );
    return KanbanTask.fromJson(unwrapApiData<Map<String, dynamic>>(res));
  }

  Future<KanbanTaskDetail> getTask(String taskId) async {
    final res = await _client.get(ApiConstants.kanbanTask(taskId));
    return KanbanTaskDetail.fromJson(unwrapApiData<Map<String, dynamic>>(res));
  }

  Future<KanbanTask> patchTask(String taskId, Map<String, dynamic> body) async {
    final res = await _client.patch(
      ApiConstants.kanbanTask(taskId),
      data: body,
    );
    return KanbanTask.fromJson(unwrapApiData<Map<String, dynamic>>(res));
  }

  Future<KanbanTask> moveTask(
    String taskId, {
    required String status,
    required int position,
  }) async {
    final res = await _client.patch(
      ApiConstants.kanbanTaskMove(taskId),
      data: {'status': status, 'position': position},
    );
    return KanbanTask.fromJson(unwrapApiData<Map<String, dynamic>>(res));
  }

  Future<void> deleteTask(String taskId) async {
    await _client.delete(ApiConstants.kanbanTask(taskId));
  }

  Future<KanbanTaskComment> createComment(
    String taskId,
    String body, {
    String? parentId,
    List<KanbanCommentAttachmentInput>? attachments,
    List<String>? mentionedUserIds,
    bool alsoSendDM = false,
  }) async {
    final res = await _client.post(
      ApiConstants.kanbanTaskComments(taskId),
      data: {
        'body': body,
        if (parentId != null && parentId.isNotEmpty) 'parent_id': parentId,
        if (attachments != null && attachments.isNotEmpty)
          'attachments': attachments.map((a) => a.toJson()).toList(),
        if (mentionedUserIds != null && mentionedUserIds.isNotEmpty)
          'mentioned_user_ids': mentionedUserIds,
        if (alsoSendDM) 'also_send_dm': true,
      },
    );
    return KanbanTaskComment.fromJson(unwrapApiData<Map<String, dynamic>>(res));
  }
}

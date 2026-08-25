import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../shared/media/picked_media_file.dart';
import 'board_attachments_api.dart';
import 'board_tasks_api.dart';
import 'models/board_models.dart';

class BoardRepository {
  const BoardRepository(this._client, this._tasksApi, this._attachmentsApi);

  final ApiClient _client;
  final BoardTasksApi _tasksApi;
  final BoardAttachmentsApi _attachmentsApi;

  Future<List<KanbanBoard>> listBoards() async {
    final res = await _client.get(ApiConstants.kanbanBoards);
    final data = unwrapApiData<List<dynamic>>(res);
    return data
        .map((e) => KanbanBoard.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<KanbanBoard?> findBoard(String boardId) async {
    final boards = await listBoards();
    for (final board in boards) {
      if (board.id == boardId) return board;
    }
    return null;
  }

  Future<List<KanbanTask>> listTasks(
    String boardId, {
    String? query,
    String? assigneeId,
  }) => _tasksApi.listTasks(boardId, query: query, assigneeId: assigneeId);

  Future<KanbanTask> createTask(String boardId, String title) =>
      _tasksApi.createTask(boardId, title);

  Future<KanbanTaskDetail> getTask(String taskId) => _tasksApi.getTask(taskId);

  Future<KanbanTask> patchTask(String taskId, Map<String, dynamic> body) =>
      _tasksApi.patchTask(taskId, body);

  Future<KanbanTask> moveTask(
    String taskId, {
    required String status,
    required int position,
  }) => _tasksApi.moveTask(taskId, status: status, position: position);

  Future<void> deleteTask(String taskId) => _tasksApi.deleteTask(taskId);

  Future<KanbanPresignResult> presignTaskAttachment(
    String taskId, {
    required String contentType,
    required String fileName,
    required int sizeBytes,
  }) => _attachmentsApi.presign(
    taskId,
    contentType: contentType,
    fileName: fileName,
    sizeBytes: sizeBytes,
  );

  Future<void> discardTaskUpload(String taskId, String fileUrl) =>
      _attachmentsApi.discard(taskId, fileUrl);

  Future<KanbanCommentAttachmentInput> uploadTaskAttachment(
    String taskId,
    PickedMediaFile file,
  ) async {
    final presign = await presignTaskAttachment(
      taskId,
      contentType: file.contentType,
      fileName: file.fileName,
      sizeBytes: file.sizeBytes,
    );
    await _attachmentsApi.uploadBytes(presign, file.bytes, file.contentType);
    return KanbanCommentAttachmentInput(
      fileUrl: presign.publicUrl,
      fileName: file.fileName,
      contentType: file.contentType,
      sizeBytes: file.sizeBytes,
    );
  }

  Future<KanbanTaskComment> createComment(
    String taskId,
    String body, {
    String? parentId,
    List<KanbanCommentAttachmentInput>? attachments,
    List<String>? mentionedUserIds,
    bool alsoSendDM = false,
  }) => _tasksApi.createComment(
    taskId,
    body,
    parentId: parentId,
    attachments: attachments,
    mentionedUserIds: mentionedUserIds,
    alsoSendDM: alsoSendDM,
  );
}

final boardAttachmentsApiProvider = Provider<BoardAttachmentsApi>(
  (ref) => BoardAttachmentsApi(ref.watch(apiClientProvider)),
);

final boardTasksApiProvider = Provider<BoardTasksApi>(
  (ref) => BoardTasksApi(ref.watch(apiClientProvider)),
);

final boardRepositoryProvider = Provider<BoardRepository>(
  (ref) => BoardRepository(
    ref.watch(apiClientProvider),
    ref.watch(boardTasksApiProvider),
    ref.watch(boardAttachmentsApiProvider),
  ),
);

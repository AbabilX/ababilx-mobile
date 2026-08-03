import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import 'models/wall_models.dart';

class WallCommentsApi {
  const WallCommentsApi(this._client);
  final ApiClient _client;

  Future<WallComment> create(
    String postId, {
    required String body,
    String? parentId,
    List<WallAttachmentInput>? attachments,
    List<String>? mentionedUserIds,
  }) async {
    final res = await _client.post(
      ApiConstants.wallPostComments(postId),
      data: {
        'body': body,
        if (parentId != null && parentId.isNotEmpty) 'parent_id': parentId,
        if (attachments != null && attachments.isNotEmpty)
          'attachments': attachments.map((a) => a.toJson()).toList(),
        if (mentionedUserIds != null && mentionedUserIds.isNotEmpty)
          'mentioned_user_ids': mentionedUserIds,
      },
    );
    return WallComment.fromJson(unwrapApiData<Map<String, dynamic>>(res));
  }

  Future<WallComment> patch(
    String postId,
    String commentId,
    String body,
  ) async {
    final res = await _client.patch(
      ApiConstants.wallPostComment(postId, commentId),
      data: {'body': body},
    );
    return WallComment.fromJson(unwrapApiData<Map<String, dynamic>>(res));
  }

  Future<void> delete(String postId, String commentId) async {
    await _client.delete(ApiConstants.wallPostComment(postId, commentId));
  }
}

class WallReactionsApi {
  const WallReactionsApi(this._client);
  final ApiClient _client;

  Future<({bool added, List<WallReactionGroup> reactions})> toggle(
    String postId, {
    required String emoji,
    String? commentId,
  }) async {
    final res = await _client.post(
      ApiConstants.wallPostReactions(postId),
      data: {'emoji': emoji, 'comment_id': commentId},
    );
    final data = unwrapApiData<Map<String, dynamic>>(res);
    final reactions = (data['reactions'] as List<dynamic>? ?? [])
        .map((e) => WallReactionGroup.fromJson(e as Map<String, dynamic>))
        .toList();
    return (added: data['added'] as bool? ?? false, reactions: reactions);
  }
}

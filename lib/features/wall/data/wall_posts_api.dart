import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import 'models/wall_models.dart';

class WallPostsApi {
  const WallPostsApi(this._client);
  final ApiClient _client;

  Future<WallPostsPage> list({
    String? cursor,
    int limit = 20,
    String? category,
    bool saved = false,
    bool mine = false,
  }) async {
    final res = await _client.get(
      ApiConstants.wallPosts,
      queryParameters: {
        if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
        'limit': limit,
        if (category != null && category.isNotEmpty) 'category': category,
        if (saved) 'saved': '1',
        if (mine) 'mine': '1',
      },
    );
    return WallPostsPage.fromJson(unwrapApiData<Map<String, dynamic>>(res));
  }

  Future<WallPost> get(String postId) async {
    final res = await _client.get(ApiConstants.wallPost(postId));
    return WallPost.fromJson(unwrapApiData<Map<String, dynamic>>(res));
  }

  Future<WallPost> create({
    required String body,
    String? category,
    List<WallAttachmentInput>? attachments,
    List<String>? mentionedUserIds,
  }) async {
    final res = await _client.post(
      ApiConstants.wallPosts,
      data: {
        'body': body,
        if (category != null && category.isNotEmpty) 'category': category,
        if (attachments != null && attachments.isNotEmpty)
          'attachments': attachments.map((a) => a.toJson()).toList(),
        if (mentionedUserIds != null && mentionedUserIds.isNotEmpty)
          'mentioned_user_ids': mentionedUserIds,
      },
    );
    return WallPost.fromJson(unwrapApiData<Map<String, dynamic>>(res));
  }

  Future<WallPost> patch(String postId, String body) async {
    final res = await _client.patch(
      ApiConstants.wallPost(postId),
      data: {'body': body},
    );
    return WallPost.fromJson(unwrapApiData<Map<String, dynamic>>(res));
  }

  Future<void> delete(String postId) async {
    await _client.delete(ApiConstants.wallPost(postId));
  }

  Future<bool> toggleSave(String postId) async {
    final res = await _client.post(ApiConstants.wallPostSave(postId));
    final data = unwrapApiData<Map<String, dynamic>>(res);
    return data['saved'] as bool? ?? false;
  }
}

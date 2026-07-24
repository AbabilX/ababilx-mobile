import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import 'models/wall_models.dart';
import 'wall_meta_api.dart';
import 'wall_posts_api.dart';
import 'wall_social_api.dart';

class WallRepository {
  WallRepository(ApiClient client)
      : _posts = WallPostsApi(client),
        _comments = WallCommentsApi(client),
        _reactions = WallReactionsApi(client),
        _attachments = WallAttachmentsApi(client),
        _meta = WallMetaApi(client);

  final WallPostsApi _posts;
  final WallCommentsApi _comments;
  final WallReactionsApi _reactions;
  final WallAttachmentsApi _attachments;
  final WallMetaApi _meta;

  Future<WallPostsPage> listPosts({
    String? cursor,
    int limit = 20,
    String? category,
    bool saved = false,
    bool mine = false,
  }) =>
      _posts.list(
        cursor: cursor,
        limit: limit,
        category: category,
        saved: saved,
        mine: mine,
      );

  Future<WallPost> getPost(String id) => _posts.get(id);

  Future<WallPost> createPost({
    required String body,
    String? category,
    List<WallAttachmentInput>? attachments,
    List<String>? mentionedUserIds,
  }) =>
      _posts.create(
        body: body,
        category: category,
        attachments: attachments,
        mentionedUserIds: mentionedUserIds,
      );

  Future<WallPost> patchPost(String id, String body) => _posts.patch(id, body);

  Future<void> deletePost(String id) => _posts.delete(id);

  Future<bool> toggleSave(String id) => _posts.toggleSave(id);

  Future<WallComment> createComment(
    String postId, {
    required String body,
    String? parentId,
    List<WallAttachmentInput>? attachments,
    List<String>? mentionedUserIds,
  }) =>
      _comments.create(
        postId,
        body: body,
        parentId: parentId,
        attachments: attachments,
        mentionedUserIds: mentionedUserIds,
      );

  Future<WallComment> patchComment(
    String postId,
    String commentId,
    String body,
  ) =>
      _comments.patch(postId, commentId, body);

  Future<void> deleteComment(String postId, String commentId) =>
      _comments.delete(postId, commentId);

  Future<({bool added, List<WallReactionGroup> reactions})> toggleReaction(
    String postId, {
    required String emoji,
    String? commentId,
  }) =>
      _reactions.toggle(postId, emoji: emoji, commentId: commentId);

  Future<WallPresignResult> presignAttachment({
    required String contentType,
    required String fileName,
    required int sizeBytes,
  }) =>
      _attachments.presign(
        contentType: contentType,
        fileName: fileName,
        sizeBytes: sizeBytes,
      );

  Future<void> discardUpload(String fileUrl) => _attachments.discard(fileUrl);

  Future<void> uploadBytes(
    WallPresignResult presign,
    Uint8List bytes,
    String contentType,
  ) =>
      _attachments.uploadBytes(presign, bytes, contentType);

  Future<List<WallCategory>> listCategories() => _meta.listCategories();

  Future<WallStats> stats() => _meta.stats();

  Future<WallSearchResponse> search(String q, {int limit = 10}) =>
      _meta.search(q, limit: limit);

  Future<int> forward({
    required String postId,
    List<String>? conversationIds,
    List<String>? userIds,
    String? caption,
  }) =>
      _meta.forward(
        postId: postId,
        conversationIds: conversationIds,
        userIds: userIds,
        caption: caption,
      );
}

final wallRepositoryProvider = Provider<WallRepository>(
  (ref) => WallRepository(ref.watch(apiClientProvider)),
);

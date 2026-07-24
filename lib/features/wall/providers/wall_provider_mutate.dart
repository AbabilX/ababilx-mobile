part of 'wall_provider.dart';

mixin _WallMutateMixin on Notifier<WallState> {
  WallRepository get repo;

  Future<WallPost> createPost({
    required String body,
    String? category,
    List<WallAttachmentInput>? attachments,
    List<String>? mentionedUserIds,
  }) async {
    final post = await repo.createPost(
      body: body,
      category: category,
      attachments: attachments,
      mentionedUserIds: mentionedUserIds,
    );
    (this as WallNotifier).prependPost(post);
    return post;
  }

  Future<void> deletePost(String postId) async {
    await repo.deletePost(postId);
    (this as WallNotifier).removePostLocal(postId);
  }

  Future<void> patchPost(String postId, String body) async {
    final updated = await repo.patchPost(postId, body);
    (this as WallNotifier)._patchPost(postId, (_) => updated);
  }

  Future<void> toggleSave(String postId) async {
    final saved = await repo.toggleSave(postId);
    (this as WallNotifier)._patchPost(
      postId,
      (p) => p.copyWith(savedByMe: saved),
    );
  }

  Future<void> react(String postId, String emoji, {String? commentId}) async {
    final result = await repo.toggleReaction(
      postId,
      emoji: emoji,
      commentId: commentId,
    );
    if (commentId == null) {
      (this as WallNotifier)._patchPost(
        postId,
        (p) => p.copyWith(reactions: result.reactions),
      );
      return;
    }
    (this as WallNotifier)._patchPost(postId, (p) {
      final comments = [
        for (final c in p.comments)
          if (c.id == commentId)
            c.copyWith(reactions: result.reactions)
          else
            c,
      ];
      return p.copyWith(comments: comments);
    });
  }

  Future<WallComment> addComment(
    String postId, {
    required String body,
    String? parentId,
    List<WallAttachmentInput>? attachments,
    List<String>? mentionedUserIds,
  }) async {
    final comment = await repo.createComment(
      postId,
      body: body,
      parentId: parentId,
      attachments: attachments,
      mentionedUserIds: mentionedUserIds,
    );
    (this as WallNotifier)._patchPost(postId, (p) {
      return p.copyWith(
        comments: [...p.comments, comment],
        commentCount: p.commentCount + 1,
      );
    });
    return comment;
  }

  Future<void> deleteComment(String postId, String commentId) async {
    await repo.deleteComment(postId, commentId);
    (this as WallNotifier)._patchPost(postId, (p) {
      return p.copyWith(
        comments: p.comments.where((c) => c.id != commentId).toList(),
        commentCount: (p.commentCount - 1).clamp(0, 1 << 30),
      );
    });
  }

  Future<int> forwardPost({
    required String postId,
    List<String>? conversationIds,
    List<String>? userIds,
    String? caption,
  }) =>
      repo.forward(
        postId: postId,
        conversationIds: conversationIds,
        userIds: userIds,
        caption: caption,
      );

  Future<WallPresignResult> presignAttachment({
    required String contentType,
    required String fileName,
    required int sizeBytes,
  }) =>
      repo.presignAttachment(
        contentType: contentType,
        fileName: fileName,
        sizeBytes: sizeBytes,
      );

  Future<void> uploadBytes(
    WallPresignResult presign,
    List<int> bytes,
    String contentType,
  ) =>
      repo.uploadBytes(
        presign,
        Uint8List.fromList(bytes),
        contentType,
      );

  Future<void> discardUpload(String fileUrl) => repo.discardUpload(fileUrl);
}

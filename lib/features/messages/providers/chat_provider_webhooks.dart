part of 'chat_provider.dart';

/// Webhook feeds: create one, replace its secret, set its picture.
///
/// A feed lands in `state.channels` like any other workspace channel — the
/// server already tells every client it is read-only through `can_message`,
/// so nothing here has to keep a second copy of that rule.
mixin _ChatWebhooksMixin
    on Notifier<ChatState>, _ChatPatchMixin, _ChatMutateMixin {
  @override
  ChatRepository get repo;

  /// Creates the feed and returns it together with the one response that
  /// carries the secret URL. The caller must show that URL immediately:
  /// nothing on the device or the server can produce it again.
  Future<({ChatConversation conversation, ChatWebhookCreated created})>
  createWebhookChannel({
    required String name,
    bool isPrivate = false,
  }) async {
    final result = await repo.createWebhookChannel(
      name: name,
      slug: slugifyChannel(name),
      isPrivate: isPrivate,
    );
    if (!isDisposed) upsertChannel(result.conversation);
    return result;
  }

  /// Mints a new URL and kills the previous one in the same call. There is no
  /// way back to the old secret, which is why every caller confirms first.
  Future<ChatWebhookCreated> regenerateWebhook(String conversationId) =>
      repo.regenerateWebhook(conversationId);

  /// Uploads a feed picture and saves it. Returns the stored URL, or '' when
  /// [bytes] is null, which clears the picture and deletes the object.
  ///
  /// The upload goes through the webhook's own presign, not the conversation
  /// attachment one: the server refuses an avatar URL that does not sit under
  /// this feed's storage prefix.
  Future<String> setWebhookAvatar(
    String conversationId,
    List<int>? bytes,
  ) async {
    if (bytes == null) return repo.saveWebhookAvatar(conversationId, '');
    final presign = await repo.presignWebhookAvatar(
      conversationId,
      contentType: 'image/jpeg',
      sizeBytes: bytes.length,
    );
    await uploadAttachmentBytes(presign, bytes, 'image/jpeg');
    return repo.saveWebhookAvatar(conversationId, presign.publicUrl);
  }
}

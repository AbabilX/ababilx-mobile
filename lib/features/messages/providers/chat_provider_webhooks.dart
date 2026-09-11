part of 'chat_provider.dart';

/// Webhook feeds: create one, replace its secret, set its picture.
///
/// A feed lands in `state.channels` like any other group — the server already
/// tells every client it is read-only through `can_message`, so nothing here
/// has to keep a second copy of that rule.
///
/// Every feed belongs to an account: a workspace feed was converted in place by
/// the server's migration 0145, so there is one kind and one route set.
mixin _ChatWebhooksMixin
    on Notifier<ChatState>, _ChatPatchMixin, _ChatMutateMixin {
  @override
  ChatRepository get repo;

  /// Creates the feed and returns it together with the one response that
  /// carries the secret URL. The caller must show that URL immediately:
  /// nothing on the device or the server can produce it again.
  ///
  /// A feed takes only a name — it has no slug, and with no team there is
  /// nobody a public feed could be open to.
  Future<({ChatConversation conversation, ChatWebhookCreated created})>
  createWebhookChannel({required String name}) async {
    final result = await repo.createWebhookChannel(name: name);
    if (!isDisposed) upsertChannel(result.conversation);
    return result;
  }

  /// Mints a new URL and kills the previous one in the same call. There is no
  /// way back to the old secret, which is why every caller confirms first.
  Future<ChatWebhookCreated> regenerateWebhook(ChatConversation feed) =>
      repo.regenerateWebhook(feed.id);

  /// Uploads a feed picture and saves it. Returns the stored URL, or '' when
  /// [bytes] is null, which clears the picture and deletes the object.
  ///
  /// The upload goes through the webhook's own presign, not the conversation
  /// attachment one: the server refuses an avatar URL that does not sit under
  /// this feed's storage prefix.
  Future<String> setWebhookAvatar(
    ChatConversation feed,
    List<int>? bytes,
  ) async {
    if (bytes == null) return _storeWebhookAvatar(feed, '');
    final presign = await repo.presignWebhookAvatar(
      feed.id,
      contentType: 'image/jpeg',
      sizeBytes: bytes.length,
    );
    await uploadAttachmentBytes(presign, bytes, 'image/jpeg');
    return _storeWebhookAvatar(feed, presign.publicUrl);
  }

  /// Saves the picture and puts it on the conversation this device already
  /// holds.
  ///
  /// The server mirrors the webhook's avatar onto the conversation row, which
  /// is what every list row, header and details screen draws — but the sidebar
  /// is not refetched after a save, so without this the photo went up, came
  /// back saved, and nothing on screen changed until the next cold start.
  Future<String> _storeWebhookAvatar(ChatConversation feed, String url) async {
    final saved = await repo.saveWebhookAvatar(feed.id, url);
    if (!isDisposed) {
      final current = state.conversationById(feed.id) ?? feed;
      upsertChannel(current.copyWith(avatarUrl: saved));
    }
    return saved;
  }
}

part of 'chat_provider.dart';

/// Rows the server lists with no last message, filled from this phone's own
/// newest message.
///
/// After "start fresh" the server hides every earlier message from this
/// account for good, so each row arrives with no preview — and a chat whose
/// history came back from a local backup read "No messages yet" over a
/// timeline full of messages. Only an empty row is touched: when the server
/// has a preview, it is the newer message.
mixin _ChatLocalPreviewMixin on Notifier<ChatState> {
  Future<List<ChatConversation>> withLocalPreviews(
    List<ChatConversation> rows,
    String userId,
  ) {
    final vault = ref.read(messageVaultProvider);
    if (vault.isStartingNewChat || userId.isEmpty) return Future.value(rows);
    final store = ref.read(chatMessageStoreProvider);
    return Future.wait(
      rows.map((row) async {
        if ((row.lastMessageAt ?? '').isNotEmpty) return row;
        try {
          final newest = await store.page(row.id, limit: 1);
          if (newest.isEmpty) return row;
          return _previewOf(
            row,
            await vault.decryptMessage(newest.first, userId),
          );
        } catch (_) {
          return row;
        }
      }),
    );
  }

  ChatConversation _previewOf(ChatConversation row, ChatMessage message) {
    final atts = [
      for (final a in message.attachments)
        ChatLastAttachment(fileName: a.fileName, contentType: a.contentType),
    ];
    final first = atts.isNotEmpty ? atts.first : null;
    return withLastMessageCipher(
      row.copyWith(
        lastMessageAt: message.createdAt,
        // Never "Unable to decrypt" down the list; see decryptPreviews.
        // A message of files only has no text; its chips are the preview.
        lastMessageBody:
            isVaultPlaceholderBody(message.body) && !_filesOnly(message)
            ? 'Encrypted message'
            : message.body,
        lastMessageUserId: message.userId,
        lastMessageAttachmentType: first?.contentType,
        lastMessageAttachmentName: first?.fileName,
        lastMessageAttachments: atts,
        clearLastMessageAttachment: atts.isEmpty,
      ),
      message,
    );
  }
}

/// Opened, and it has no text: nothing but attachments.
bool _filesOnly(ChatMessage message) =>
    message.body.isEmpty && message.attachments.isNotEmpty;

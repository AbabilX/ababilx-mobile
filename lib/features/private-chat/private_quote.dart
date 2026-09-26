import '../messages/data/local/chat_message_store.dart';
import '../messages/data/models/chat_message.dart';
import '../messages/data/models/chat_message_quote.dart';

/// What a private-chat reply quotes, from this phone's own history (server
/// 0160). The reply carries only the id, and only a message of the SAME
/// conversation may answer it: the id came from the other phone, and a quote
/// is drawn with that message's text.
Future<ChatMessageQuote?> resolvePrivateQuote(
  ChatMessageStore store,
  String conversationId,
  String messageId,
) async {
  final original = await store.byId(messageId);
  if (original == null || original.conversationId != conversationId) {
    return null;
  }
  return quoteOf(original);
}

/// The quote card a stored message would get from the server's join.
ChatMessageQuote quoteOf(ChatMessage m) => ChatMessageQuote(
  messageId: m.id,
  userId: m.userId,
  userName: m.userName,
  body: m.isEncrypted ? '' : m.body,
  encryptedBody: m.encryptedBody,
  encryptionNonce: m.encryptionNonce,
  encryptionKeyVersion: m.encryptionKeyVersion,
  attachmentType: m.attachments.isEmpty
      ? null
      : m.attachments.first.contentType,
  deleted: m.isDeleted,
);

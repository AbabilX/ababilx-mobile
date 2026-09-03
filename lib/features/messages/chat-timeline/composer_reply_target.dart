import '../data/models/chat_models.dart';
import '../tiptap_plain_text.dart';

/// How a Reply is sent, resolved from where the composer is.
///
/// The app has both models and they mean different things. In the main
/// timeline a reply is a **quote**: the message stays in the timeline and shows
/// a preview of what it answers, like Signal. Inside a thread sheet the reply
/// belongs to that thread, so [parentId] is the thread root and there is no
/// quote — the thread already shows what is being answered.
///
/// Never set both from the same reply: `parent_id` takes a message out of the
/// main feed (the server lists it with `parent_id IS NULL`), so a quoted reply
/// that also carried a parent would quietly vanish from the conversation.
class ComposerReplyTarget {
  const ComposerReplyTarget({
    this.parentId,
    this.quotedMessageId,
    this.preview,
  });

  final String? parentId;
  final String? quotedMessageId;

  /// Optimistic quote for the pending bubble, so the reply renders complete
  /// before the server answers.
  final ChatMessageQuote? preview;

  factory ComposerReplyTarget.resolve({
    required ChatMessage? replyTo,
    required String? threadRootId,
  }) {
    if (threadRootId != null && threadRootId.isNotEmpty) {
      return ComposerReplyTarget(parentId: threadRootId);
    }
    if (replyTo == null) return const ComposerReplyTarget();
    return ComposerReplyTarget(
      quotedMessageId: replyTo.id,
      preview: ChatMessageQuote(
        messageId: replyTo.id,
        userId: replyTo.userId,
        userName: replyTo.userName,
        // Already decrypted on screen; the confirmed message carries the
        // server's own copy and replaces this.
        body: tiptapToPreviewText(replyTo.body),
        attachmentType: replyTo.attachments.isEmpty
            ? null
            : replyTo.attachments.first.contentType,
      ),
    );
  }
}

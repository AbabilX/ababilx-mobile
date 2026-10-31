import '../../chat_utils.dart';
import '../../data/models/chat_message.dart';
import '../../tiptap_plain_text.dart';

/// Who sent the media and what they wrote — the reference app's toolbar +
/// caption.
///
/// Shared-media cells omit this; the viewer then titles the page with the
/// file name rather than inventing a sender it does not have.
class ChatMediaPreviewMeta {
  const ChatMediaPreviewMeta({
    required this.title,
    this.subtitle,
    this.caption,
  });

  /// "You" on an outgoing row, the sender (or nickname) on an incoming one.
  final String title;

  /// Relative time, same wording as the rest of chat (`formatChatTime`).
  final String? subtitle;

  /// Plain body under the photo. Null when the message is media-only.
  final String? caption;

  /// Second toolbar line: "You · 10:00 AM". The file name is the title.
  String? get detail {
    final who = title.trim();
    final when = subtitle?.trim() ?? '';
    if (who.isEmpty) return when.isEmpty ? null : when;
    if (when.isEmpty) return who;
    return '$who · $when';
  }

  static ChatMediaPreviewMeta of({
    required ChatMessage message,
    required bool isOwn,
    required String senderName,
  }) {
    final caption = tiptapToPlainText(message.body).trim();
    final subtitle = formatChatTime(message.createdAt);
    return ChatMediaPreviewMeta(
      title: message.isWebhook
          ? (message.webhookSourceName ?? 'Flock')
          : (isOwn ? 'You' : senderName),
      subtitle: subtitle.isEmpty ? null : subtitle,
      caption: caption.isEmpty ? null : caption,
    );
  }
}

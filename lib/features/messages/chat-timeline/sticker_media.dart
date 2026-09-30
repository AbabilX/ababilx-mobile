import '../data/models/chat_models.dart';

/// A picture whose format can carry transparency: a keyboard sticker (PNG or
/// WebP) or a GIF. Such a picture is drawn with nothing behind it — the
/// placeholder fill under an ordinary photo would show through every clear
/// pixel and turn the sticker into a grey block. An opaque PNG or GIF looks
/// the same either way, so the format alone decides.
bool isStickerLike(ChatMessageAttachment attachment) {
  if (!attachment.isImage) return false;
  final type = attachment.contentType.split(';').first.trim().toLowerCase();
  if (_types.contains(type)) return true;
  final name = attachment.fileName.toLowerCase();
  return _extensions.any(name.endsWith);
}

/// A bubble that is one sticker-like picture and nothing else: no fill, no
/// caption, the time in its own small pill under the picture's corner.
bool isStickerMessage(ChatMessage message) {
  if (message.attachments.length != 1) return false;
  final only = message.attachments.single;
  return !only.timed && !only.expired && isStickerLike(only);
}

const _types = {'image/gif', 'image/webp', 'image/png'};
const _extensions = ['.gif', '.webp', '.png'];

/// What a chat push says about its attachments, from the `att_kind` /
/// `att_count` fields the server adds.
///
/// Server twin: `ababilx-server/services/chat/notify_push_attachments.go`
/// (`pushAttachmentLabel`). Same words, so an iOS placeholder drawn by the
/// server and an Android entry drawn here read alike.
class ChatPushAttachments {
  const ChatPushAttachments({required this.kind, required this.count});

  /// Null when the push names no attachment (or came from an older server).
  static ChatPushAttachments? of(Map<String, dynamic> data) {
    final kind = data['att_kind']?.toString() ?? '';
    final count = int.tryParse(data['att_count']?.toString() ?? '') ?? 0;
    if (kind.isEmpty || count <= 0) return null;
    return ChatPushAttachments(kind: kind, count: count);
  }

  final String kind;
  final int count;

  /// A single photo is the one case worth drawing in the tray.
  bool get isSinglePhoto => kind == 'photo' && count == 1;

  String get icon => switch (kind) {
    'photo' => '📷',
    'video' => '🎥',
    'voice' => '🎤',
    'audio' => '🎵',
    _ => '📎',
  };

  /// "📷 Photo", "📷 3 photos", "📎 2 attachments".
  String get label {
    if (kind == 'mixed') return '📎 $count attachments';
    final (one, many) = switch (kind) {
      'photo' => ('Photo', 'photos'),
      'video' => ('Video', 'videos'),
      'voice' => ('Voice message', 'voice messages'),
      'audio' => ('Audio', 'audio files'),
      _ => ('File', 'files'),
    };
    return count == 1 ? '$icon $one' : '$icon $count $many';
  }

  /// The line for a message with this caption: the caption behind the icon,
  /// or the label alone when there is no caption.
  String line(String? caption) {
    final text = caption?.trim() ?? '';
    return text.isEmpty ? label : '$icon $text';
  }
}

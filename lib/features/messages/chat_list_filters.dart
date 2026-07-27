import 'package:intl/intl.dart';

import 'data/models/chat_models.dart';
import 'tiptap_plain_text.dart';

enum ChatListFilter { all, unread }

List<ChatConversation> unifiedConversations({
  required List<ChatConversation> dms,
  required List<ChatConversation> channels,
  ChatListFilter filter = ChatListFilter.all,
}) {
  final all = [...dms, ...channels];
  all.sort((a, b) {
    final ta =
        DateTime.tryParse(a.lastMessageAt ?? '')?.millisecondsSinceEpoch ?? 0;
    final tb =
        DateTime.tryParse(b.lastMessageAt ?? '')?.millisecondsSinceEpoch ?? 0;
    return tb.compareTo(ta);
  });
  if (filter == ChatListFilter.unread) {
    return all.where((c) => c.unreadCount > 0).toList();
  }
  return all;
}

List<ChatConversation> recentDmsForStrip(
  List<ChatConversation> dms, {
  int limit = 12,
}) {
  final copy = [...dms];
  copy.sort((a, b) {
    final ta =
        DateTime.tryParse(a.lastMessageAt ?? '')?.millisecondsSinceEpoch ?? 0;
    final tb =
        DateTime.tryParse(b.lastMessageAt ?? '')?.millisecondsSinceEpoch ?? 0;
    return tb.compareTo(ta);
  });
  return copy.take(limit).toList();
}

String relativeChatTime(String? iso) {
  if (iso == null || iso.isEmpty) return '';
  final dt = DateTime.tryParse(iso)?.toLocal();
  if (dt == null) return '';
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final messageDay = DateTime(dt.year, dt.month, dt.day);
  final days = today.difference(messageDay).inDays;
  if (days == 0) return DateFormat.jm().format(dt);
  if (days == 1) return 'Yesterday';
  if (days < 7) return DateFormat.EEEE().format(dt);
  if (dt.year == now.year) return DateFormat('d MMMM').format(dt);
  return DateFormat('d MMM yy').format(dt);
}

/// Slack-style list preview: text (+ optional You:) and file badges.
class ChatListPreview {
  const ChatListPreview({
    required this.text,
    this.fromMe = false,
    this.files = const [],
  });

  final String text;
  final bool fromMe;
  final List<ChatLastAttachment> files;

  bool get hasText => text.trim().isNotEmpty;
  bool get hasFiles => files.isNotEmpty;

  String get display {
    if (!hasText && !hasFiles) return 'No messages yet';
    if (!hasText) return fromMe ? 'You: ' : '';
    return fromMe ? 'You: $text' : text;
  }
}

ChatListPreview chatListPreview(
  ChatConversation conv,
  String? currentUserId,
) {
  final rawBody = conv.lastMessageBody?.trim() ?? '';
  final hasBody = rawBody.isNotEmpty && !isTiptapEmpty(rawBody);
  var text = '';

  if (hasBody) {
    text = tiptapToPlainText(rawBody).trim();
    if (text.isEmpty || _looksLikeJson(text)) {
      text = extractFromBrokenTiptapJson(rawBody).trim();
    }
    if (_looksLikeJson(text)) text = '';
  }

  final files = conv.previewAttachments
      .where((a) => a.fileName.trim().isNotEmpty || a.contentType.isNotEmpty)
      .toList();

  // Text-only fallback when there is no body but also no file chips yet.
  if (text.isEmpty && files.isEmpty && hasBody) {
    text = 'Message';
  }

  final me = currentUserId?.trim() ?? '';
  final sender = conv.lastMessageUserId?.trim() ?? '';
  final fromMe = me.isNotEmpty && sender.isNotEmpty && sender == me;

  return ChatListPreview(text: text, fromMe: fromMe, files: files);
}

/// Back-compat wrapper used by tests / older call sites.
String previewWithYou(ChatConversation conv, String? currentUserId) {
  final p = chatListPreview(conv, currentUserId);
  if (!p.hasText && p.hasFiles) {
    final label = p.files.first.fileName.trim().isNotEmpty
        ? p.files.first.fileName.trim()
        : 'Attachment';
    return p.fromMe ? 'You: $label' : label;
  }
  return p.display.isEmpty ? 'No messages yet' : p.display;
}

bool _looksLikeJson(String value) {
  final t = value.trim();
  return t.startsWith('{') && t.contains('"type"');
}

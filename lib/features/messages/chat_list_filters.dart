import 'package:intl/intl.dart';

import '../jpack/data/jpack_preview.dart';
import 'data/models/chat_models.dart';
import 'tiptap_plain_text.dart';

enum ChatListFilter { all, unread }

List<ChatConversation> unifiedConversations({
  required List<ChatConversation> dms,
  required List<ChatConversation> channels,
  ChatListFilter filter = ChatListFilter.all,
}) {
  final all = [...dms, ...channels];
  // Pinned first, and inside each block the same newest-first order. A pin
  // says "keep this reachable", not "freeze it in place", so a pinned chat
  // still rises within its block when it gets a message — which is why this
  // is one comparator with a leading key rather than two sorted lists.
  all.sort((a, b) {
    if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
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
    this.mentionLabels = const [],
  });

  final String text;
  final bool fromMe;
  final List<ChatLastAttachment> files;

  /// TipTap mention labels for this preview body — used to colour spaced
  /// display names as one chip (`@John Doe`), not only `@John`.
  final List<String> mentionLabels;

  bool get hasText => text.trim().isNotEmpty;
  bool get hasFiles => files.isNotEmpty;

  String get display {
    if (!hasText && !hasFiles) return 'No messages yet';
    if (!hasText) return fromMe ? 'You: ' : '';
    return fromMe ? 'You: $text' : text;
  }
}

ChatListPreview chatListPreview(ChatConversation conv, String? currentUserId) {
  final rawBody = conv.lastMessageBody?.trim() ?? '';
  final hasBody = rawBody.isNotEmpty && !isTiptapEmpty(rawBody);
  var text = '';

  final jpack = hasBody ? jpackPreviewText(rawBody) : null;
  if (jpack != null) {
    text = jpack;
  } else if (hasBody) {
    text = tiptapToPreviewText(rawBody);
    if (text.isEmpty || _looksLikeJson(text)) {
      text = extractFromBrokenTiptapJson(rawBody).trim();
    }
    if (_looksLikeJson(text)) text = '';
  }

  final files = conv.previewAttachments
      .where((a) => a.fileName.trim().isNotEmpty || a.contentType.isNotEmpty)
      .toList();

  // If the body exists but tiptap parsing yields nothing (e.g. the API
  // truncated the JSON at 120 chars), leave text empty so the preview shows
  // the file chips or the natural "No messages yet" empty state rather than
  // the misleading literal word "Message".
  if (text.isEmpty && files.isEmpty && hasBody) {
    text = '';
  }

  final me = currentUserId?.trim() ?? '';
  final sender = conv.lastMessageUserId?.trim() ?? '';
  // Call history rows are system-like — never "You: Missed voice call".
  final looksLikeCall = _looksLikeVoiceCallPreview(text);
  final fromMe =
      !looksLikeCall && me.isNotEmpty && sender.isNotEmpty && sender == me;

  final mentionLabels = hasBody ? tiptapMentionLabels(rawBody) : const <String>[];

  return ChatListPreview(
    text: text,
    fromMe: fromMe,
    files: files,
    mentionLabels: mentionLabels,
  );
}

bool _looksLikeVoiceCallPreview(String text) {
  final t = text.toLowerCase();
  return t.contains('voice call') ||
      t == 'no answer' ||
      t.contains('missed voice call');
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

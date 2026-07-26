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
  if (dt.year == now.year) return DateFormat('d MMM').format(dt);
  return DateFormat('d MMM yy').format(dt);
}

String previewWithYou(ChatConversation conv, String? currentUserId) {
  final body = tiptapToPlainText(conv.lastMessageBody).trim();
  final base = () {
    if (body.isNotEmpty) return body;
    final type = conv.lastMessageAttachmentType?.toLowerCase() ?? '';
    if (type.startsWith('image/')) return 'Photo';
    if (type.startsWith('audio/')) return 'Voice message';
    if (type.isNotEmpty) {
      return conv.lastMessageAttachmentName?.trim().isNotEmpty == true
          ? conv.lastMessageAttachmentName!.trim()
          : 'Attachment';
    }
    return 'No messages yet';
  }();
  if (conv.lastMessageUserId != null &&
      currentUserId != null &&
      conv.lastMessageUserId == currentUserId) {
    return 'You: $base';
  }
  return base;
}

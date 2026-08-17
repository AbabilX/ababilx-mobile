import 'package:intl/intl.dart';

import 'data/models/chat_models.dart';
import 'tiptap_plain_text.dart';

String formatChatTime(String? iso) {
  if (iso == null || iso.isEmpty) return '';
  final dt = DateTime.tryParse(iso);
  if (dt == null) return '';
  final local = dt.toLocal();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(local.year, local.month, local.day);
  if (day == today) {
    return DateFormat.jm().format(local);
  }
  if (day == today.subtract(const Duration(days: 1))) {
    return 'Yesterday ${DateFormat.jm().format(local)}';
  }
  return DateFormat('MMM d, h:mm a').format(local);
}

String formatDateDivider(String? iso) {
  if (iso == null || iso.isEmpty) return '';
  final dt = DateTime.tryParse(iso);
  if (dt == null) return '';
  final local = dt.toLocal();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(local.year, local.month, local.day);
  if (day == today) return 'Today';
  if (day == today.subtract(const Duration(days: 1))) return 'Yesterday';
  return DateFormat('MMMM d, yyyy').format(local);
}

bool isSameDay(String? a, String? b) {
  if (a == null || b == null) return false;
  final da = DateTime.tryParse(a)?.toLocal();
  final db = DateTime.tryParse(b)?.toLocal();
  if (da == null || db == null) return false;
  return da.year == db.year && da.month == db.month && da.day == db.day;
}

String slugifyChannel(String name) {
  return name
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9\s-]'), '')
      .replaceAll(RegExp(r'\s+'), '-')
      .replaceAll(RegExp(r'-+'), '-');
}

String conversationPreview(ChatConversation conv) {
  if (conv.lastMessageAttachmentType != null) {
    final name = conv.lastMessageAttachmentName;
    if (conv.lastMessageAttachmentType!.startsWith('image/')) {
      return name != null ? 'Photo: $name' : 'Photo';
    }
    return name != null ? 'File: $name' : 'Attachment';
  }
  final body = tiptapToPreviewText(conv.lastMessageBody).trim();
  if (body.isNotEmpty) return body;
  return 'No messages yet';
}

const convIdRe =
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$';

bool isValidConversationId(String? id) {
  if (id == null || id.isEmpty) return false;
  return RegExp(convIdRe, caseSensitive: false).hasMatch(id);
}

String feedKey(String conversationId, {String? threadRootId}) {
  if (threadRootId != null && threadRootId.isNotEmpty) {
    return '$conversationId:thread:$threadRootId';
  }
  return conversationId;
}

List<ChatConversation> sortDms(List<ChatConversation> dms) {
  final copy = [...dms];
  copy.sort((a, b) {
    final aUnread = a.unreadCount > 0 ? 1 : 0;
    final bUnread = b.unreadCount > 0 ? 1 : 0;
    if (aUnread != bUnread) return bUnread - aUnread;
    final ta =
        DateTime.tryParse(a.lastMessageAt ?? '')?.millisecondsSinceEpoch ?? 0;
    final tb =
        DateTime.tryParse(b.lastMessageAt ?? '')?.millisecondsSinceEpoch ?? 0;
    return tb.compareTo(ta);
  });
  return copy;
}

List<ChatConversation> sortChannels(List<ChatConversation> channels) {
  final copy = [...channels];
  copy.sort((a, b) {
    final aUnread = a.unreadCount > 0 ? 1 : 0;
    final bUnread = b.unreadCount > 0 ? 1 : 0;
    if (aUnread != bUnread) return bUnread - aUnread;
    final la = (a.name ?? a.slug ?? '').toLowerCase();
    final lb = (b.name ?? b.slug ?? '').toLowerCase();
    return la.compareTo(lb);
  });
  return copy;
}

int totalUnread(List<ChatConversation> dms, List<ChatConversation> channels) {
  var sum = 0;
  for (final c in dms) {
    sum += c.unreadCount;
  }
  for (final c in channels) {
    sum += c.unreadCount;
  }
  return sum;
}

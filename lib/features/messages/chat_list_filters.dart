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
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1) return 'now';
  if (diff.inHours < 1) return '${diff.inMinutes}m';
  if (diff.inHours < 24) return '${diff.inHours}h';
  if (diff.inDays < 7) return '${diff.inDays}d';
  return '${(diff.inDays / 7).floor()}w';
}

String previewWithYou(
  ChatConversation conv,
  String? currentUserId,
) {
  final body = tiptapToPlainText(conv.lastMessageBody).trim();
  final base = () {
    if (conv.lastMessageAttachmentType != null) {
      if (conv.lastMessageAttachmentType!.startsWith('image/')) return 'Photo';
      return 'Attachment';
    }
    if (body.isNotEmpty) return body;
    return 'No messages yet';
  }();
  if (conv.lastMessageUserId != null &&
      currentUserId != null &&
      conv.lastMessageUserId == currentUserId) {
    return 'You: $base';
  }
  return base;
}

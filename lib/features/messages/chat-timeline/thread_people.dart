import '../data/models/chat_models.dart';
import '../tiptap_plain_text.dart';

class ThreadPerson {
  const ThreadPerson({required this.userId, this.name, this.avatarUrl});

  final String userId;
  final String? name;
  final String? avatarUrl;
}

/// Unique authors on the thread (newest first), max 3. The root is included
/// even when replies have not been fetched yet — that is how the card still
/// draws a face on the main timeline.
List<ThreadPerson> threadParticipants(
  ChatMessage root,
  List<ChatMessage> replies, {
  int max = 3,
}) {
  final byUser = <String, ({ThreadPerson person, int latest})>{};

  void consider(ChatMessage m) {
    if (m.userId.isEmpty) return;
    final ts = DateTime.tryParse(m.createdAt)?.millisecondsSinceEpoch ?? 0;
    final existing = byUser[m.userId];
    if (existing == null || ts > existing.latest) {
      byUser[m.userId] = (
        person: ThreadPerson(
          userId: m.userId,
          name: m.userName,
          avatarUrl: m.userAvatarUrl,
        ),
        latest: ts,
      );
    }
  }

  consider(root);
  for (final m in replies) {
    consider(m);
  }

  final ranked = byUser.values.toList()
    ..sort((a, b) => b.latest.compareTo(a.latest));
  return ranked.take(max).map((e) => e.person).toList();
}

ChatMessage? lastReplyMessage(List<ChatMessage> replies) {
  if (replies.isEmpty) return null;
  ChatMessage latest = replies.first;
  var latestTs =
      DateTime.tryParse(latest.createdAt)?.millisecondsSinceEpoch ?? 0;
  for (final m in replies.skip(1)) {
    final ts = DateTime.tryParse(m.createdAt)?.millisecondsSinceEpoch ?? 0;
    if (ts > latestTs) {
      latest = m;
      latestTs = ts;
    }
  }
  return latest;
}

/// Last reply text when prefetch (or an opened thread) has filled the
/// replies. Empty until then — [thread_count] already said there are
/// replies, so a "no messages" line would be a lie.
String threadPreview(List<ChatMessage> replies) {
  final latest = lastReplyMessage(replies);
  if (latest == null) return '';
  final plain = tiptapToPreviewText(latest.body);
  if (plain.isNotEmpty) return plain;
  if (latest.attachments.isNotEmpty) return 'Sent an attachment';
  return '';
}

String threadReplyLabel(int replyCount) {
  return replyCount == 1 ? '1 reply' : '$replyCount replies';
}

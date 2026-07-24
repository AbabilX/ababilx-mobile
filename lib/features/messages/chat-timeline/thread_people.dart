import '../data/models/chat_models.dart';

class ThreadPerson {
  const ThreadPerson({
    required this.userId,
    this.name,
    this.avatarUrl,
  });

  final String userId;
  final String? name;
  final String? avatarUrl;
}

/// Unique reply authors (newest first), max 3. Falls back to root author.
List<ThreadPerson> threadParticipants(
  ChatMessage root,
  List<ChatMessage> replies, {
  int max = 3,
}) {
  final byUser = <String, ({ThreadPerson person, int latest})>{};

  void consider(ChatMessage m) {
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

  for (final m in replies) {
    consider(m);
  }
  if (byUser.isEmpty) consider(root);

  final ranked = byUser.values.toList()
    ..sort((a, b) => b.latest.compareTo(a.latest));
  return ranked.take(max).map((e) => e.person).toList();
}

String? latestReplyAt(List<ChatMessage> replies) {
  if (replies.isEmpty) return null;
  ChatMessage latest = replies.first;
  var latestTs = DateTime.tryParse(latest.createdAt)?.millisecondsSinceEpoch ?? 0;
  for (final m in replies.skip(1)) {
    final ts = DateTime.tryParse(m.createdAt)?.millisecondsSinceEpoch ?? 0;
    if (ts > latestTs) {
      latest = m;
      latestTs = ts;
    }
  }
  return latest.createdAt;
}

String formatRelativeAgo(String? iso) {
  if (iso == null || iso.isEmpty) return '';
  final dt = DateTime.tryParse(iso)?.toLocal();
  if (dt == null) return '';
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24) {
    return '${diff.inHours} ${diff.inHours == 1 ? 'hour' : 'hours'} ago';
  }
  if (diff.inDays == 1) return '1 day ago';
  if (diff.inDays < 7) return '${diff.inDays} days ago';
  return '${dt.month}/${dt.day}';
}

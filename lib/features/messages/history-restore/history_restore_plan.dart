import '../data/models/chat_models.dart';

/// Conversations that still have no local page, so a recovery restore should
/// fetch their newest server page.
///
/// Already-open feeds and chats that landed on disk (the user opened one
/// while the job ran, or a previous attempt finished) are skipped so a
/// resume never re-downloads.
List<String> conversationIdsNeedingRestore({
  required Iterable<ChatConversation> conversations,
  required Set<String> alreadyOnDisk,
  required Set<String> alreadyLive,
}) {
  final seen = <String>{};
  final ids = <String>[];
  for (final conversation in conversations) {
    final id = conversation.id.trim();
    if (id.isEmpty || !seen.add(id)) continue;
    if (alreadyOnDisk.contains(id) || alreadyLive.contains(id)) continue;
    ids.add(id);
  }
  return ids;
}

import '../data/models/chat_models.dart';

String? _quotedId(ChatMessage m) {
  final id = m.quote?.messageId ?? m.privateQuoteId;
  return id == null || id.isEmpty ? null : id;
}

/// Ids of every message somebody on this phone's copy of the conversation has
/// quoted — the reference app's `hasBeenQuoted`, worked out from the loaded
/// timeline because the server sends no such flag.
Set<String> quotedMessageIds(List<ChatMessage> messages) => {
  for (final m in messages)
    if (!m.isDeleted) ?_quotedId(m),
};

/// The original message and everything that quotes it, or quotes one of
/// those, oldest first — the reference app's `getMessagesInQuoteChain`. Empty
/// when the original is not on this phone.
List<ChatMessage> quoteChain(List<ChatMessage> messages, String messageId) {
  final byId = {for (final m in messages) m.id: m};
  // Walk up to the root, as the reference app's `getRootOfQuoteChain` does. The
  // hop count bounds a cycle a hostile client could write.
  var root = byId[messageId];
  for (var hops = 0; root != null && hops < 64; hops++) {
    final parent = byId[_quotedId(root)];
    if (parent == null) break;
    root = parent;
  }
  if (root == null) return const [];

  final chain = <String>{root.id};
  var grew = true;
  while (grew) {
    grew = false;
    for (final m in messages) {
      if (m.isDeleted || chain.contains(m.id)) continue;
      if (chain.contains(_quotedId(m))) {
        chain.add(m.id);
        grew = true;
      }
    }
  }
  return [
    for (final m in messages)
      if (chain.contains(m.id)) m,
  ]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
}

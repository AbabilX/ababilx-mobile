import '../data/local/chat_message_store.dart';
import '../data/models/chat_models.dart';

/// [messages] with each one the server emptied replaced by this phone's own
/// copy, or null where the phone has none.
///
/// Under delivery-only (server 0173) a pinned message is purged to a
/// tombstone — kept so the pin survives, but with no content — once every
/// phone has it. The text, files and reactions live here now. A tombstone
/// with no local copy has nothing to show, so its pin is left out rather than
/// drawn as an empty bubble.
Future<List<ChatMessage?>> pinnedWithLocalCopies(
  ChatMessageStore store,
  List<ChatMessage> messages,
) async => [
  for (final m in messages)
    if (!m.contentPurged) m else await _localCopy(store, m),
];

Future<ChatMessage?> _localCopy(
  ChatMessageStore store,
  ChatMessage pinned,
) async {
  final local = await store.byId(pinned.id);
  if (local == null || local.contentPurged || local.isDeleted) return null;
  if (local.conversationId != pinned.conversationId) return null;
  return local;
}

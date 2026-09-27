import '../../../shared/text/name_search.dart';
import '../data/models/chat_models.dart';
import '../message_e2ee/vault_placeholder.dart';
import '../tiptap_plain_text.dart';
import 'chat_pins_provider.dart';

/// The Pins page search: a pin matches on its text, its sender's name or an
/// attachment's file name. Bodies here are already opened by the vault, so
/// an encrypted pin is searched by what it says, never by ciphertext.
bool pinMatchesQuery(ChatMessage message, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return true;
  if (matchesNameQuery(q, [message.userName])) return true;
  // A body this device never opened is a placeholder string; never match it.
  if (!isVaultPlaceholderBody(message.body) &&
      tiptapToPlainText(message.body).toLowerCase().contains(q)) {
    return true;
  }
  return message.attachments.any((a) => a.fileName.toLowerCase().contains(q));
}

/// [entries] narrowed to [query], order kept.
List<ChatPinEntry> filterPins(List<ChatPinEntry> entries, String query) =>
    query.trim().isEmpty
    ? entries
    : [
        for (final e in entries)
          if (pinMatchesQuery(e.message, query)) e,
      ];

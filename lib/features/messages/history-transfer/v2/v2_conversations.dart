import '../../data/models/chat_models.dart';

/// The conversations a message batch names, from this phone's own data.
///
/// The cached sidebar is the richest local record of a conversation — name,
/// type, members, photo — so it is used when it has the row. It does not
/// always: a group this account left, or a thread that scrolled out of the
/// cached list, still has messages on the phone. Those get a minimal frame
/// built from the messages themselves, because the destination must be able
/// to show every imported thread even when the server lists none of them.
class V2Conversations {
  V2Conversations(Iterable<ChatConversation> known)
    : _known = {for (final c in known) c.id: c};

  final Map<String, ChatConversation> _known;
  final Map<String, Map<String, dynamic>> _synthesized = {};

  int get count => _known.length + _synthesized.length;

  Map<String, dynamic> frameFor(String id, ChatMessage first) {
    final known = _known[id];
    if (known != null) {
      // The decrypted sidebar preview is plaintext of a sealed message; the
      // destination recomputes previews from the messages it stores.
      return known.toJson()..['last_message_body'] = '';
    }
    return _synthesized.putIfAbsent(
      id,
      () => {
        'id': id,
        'team_id': '',
        'scope': 'personal',
        'type': 'group',
        'name': _nameFrom(first),
        'is_private': true,
        'created_at': first.createdAt,
        'unread_count': 0,
        'local_only': true,
      },
    );
  }

  static String _nameFrom(ChatMessage message) {
    final name = (message.userName ?? '').trim();
    return name.isEmpty ? 'Conversation' : name;
  }
}

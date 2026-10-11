import 'package:shared_preferences/shared_preferences.dart';

import '../data/models/chat_conversation.dart';

/// This phone's own memory of who each DM is with.
///
/// A conversation key is sealed to the roster the server lists
/// (`e2ee-members`), and a group has no other source for it. A DM does: it is
/// between two people, and this phone has known which two since it first saw
/// the chat. Without that, one extra row in the roster — a database write is
/// enough — got a copy of the DM's key and, through backfill, of every older
/// one, with no key ever changing and so no warning. A pinned DM is sealed to
/// its own two people and nobody else, whatever the roster says.
///
/// Trust on first use, like EncryptionPins: the first peer seen for a
/// conversation is kept and never replaced. Ids are not secret, so this is
/// SharedPreferences, which the notification isolate reads too.
class DmRosterPins {
  const DmRosterPins();

  static const _prefix = 'chat_dm_peers_v1:';
  static final _memory = <String, Map<String, String>>{};
  static final _read = <String>{};

  Future<Map<String, String>> _load(
    String userId, {
    bool reload = false,
  }) async {
    final held = _memory[userId];
    if (held != null && !reload && _read.contains(userId)) return held;
    try {
      final prefs = await SharedPreferences.getInstance();
      // Another isolate may have written since this one last looked.
      if (reload) await prefs.reload();
      final peers = <String, String>{};
      for (final row in prefs.getStringList('$_prefix$userId') ?? const []) {
        final cut = row.indexOf(' ');
        if (cut > 0) peers[row.substring(0, cut)] = row.substring(cut + 1);
      }
      // What is on disk came first; a peer held only in memory fills gaps.
      held?.forEach((id, peer) => peers.putIfAbsent(id, () => peer));
      _read.add(userId);
      return _memory[userId] = peers;
    } catch (_) {
      // Unreadable storage is not the server's doing: no pin, no bound.
      return _memory[userId] = held ?? <String, String>{};
    }
  }

  /// Everyone [conversationId]'s key may be sealed to, or null when this
  /// phone has not met it as a DM (a group, or a chat never listed here).
  /// Pass [reload] from an isolate that does not write pins itself.
  Future<Set<String>?> roster(
    String userId,
    String conversationId, {
    bool reload = false,
  }) async {
    if (userId.isEmpty || conversationId.isEmpty) return null;
    final peer = (await _load(userId, reload: reload))[conversationId];
    if (peer == null) return null;
    // Note to Self is pinned with no peer: sealed to this account alone.
    return {userId, if (peer.isNotEmpty) peer};
  }

  /// Remembers the peer of every DM in [conversations] not met before.
  Future<void> observe(
    String userId,
    Iterable<ChatConversation> conversations,
  ) async {
    if (userId.isEmpty) return;
    final peers = await _load(userId);
    var added = false;
    for (final c in conversations) {
      if (!c.isDm || c.id.isEmpty || peers.containsKey(c.id)) continue;
      final peer = c.isSelf ? '' : (c.peerUserId ?? '');
      // A DM row with no peer named says nothing worth keeping.
      if (!c.isSelf && (peer.isEmpty || peer == userId)) continue;
      peers[c.id] = peer;
      added = true;
    }
    if (!added) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('$_prefix$userId', [
        for (final entry in peers.entries) '${entry.key} ${entry.value}',
      ]);
    } catch (_) {
      // Held in memory for this run; written with the next new DM.
    }
  }
}

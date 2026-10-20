import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// When the oldest sealed message this phone has opened in each conversation
/// was sent.
///
/// A sealed chat takes no plain text: the server refuses it and every client
/// seals. So a text row that arrives unsealed, newer than a sealed message
/// this phone has opened, was not written by the app of the person it names.
/// Whoever can write to the database can put one there. This is the line the
/// timeline measures against to say so (`isUnsealedText`).
///
/// Only a message that OPENED moves the line: it was sealed under the
/// conversation key, so the server cannot invent one. The line only moves
/// back in time, so the worst a false timestamp does is mark more.
///
/// Times are the server's on both sides of the comparison, never this
/// phone's clock. Not secret, so SharedPreferences, kept per account.
class SealedSince {
  const SealedSince();

  static const _prefix = 'chat_sealed_since_v1:';
  static final _memory = <String, Map<String, int>>{};
  static final _read = <String>{};
  static final _writing = <String>{};
  static final _again = <String>{};

  /// Bumped each time a line moves, for whatever is drawing marks.
  static final changes = ValueNotifier<int>(0);

  Future<Map<String, int>> _load(String userId) async {
    final held = _memory[userId];
    if (held != null && _read.contains(userId)) return held;
    try {
      final prefs = await SharedPreferences.getInstance();
      final lines = _parse(prefs.getStringList('$_prefix$userId'));
      // A line noted before the file was read keeps whichever is older.
      held?.forEach((id, at) => _lower(lines, id, at));
      _read.add(userId);
      return _memory[userId] = lines;
    } catch (_) {
      // Unreadable storage: this run keeps what it sees, and tries again.
      return _memory[userId] = held ?? <String, int>{};
    }
  }

  static Map<String, int> _parse(List<String>? rows) {
    final lines = <String, int>{};
    for (final row in rows ?? const <String>[]) {
      final cut = row.indexOf(' ');
      final at = cut > 0 ? int.tryParse(row.substring(cut + 1)) : null;
      if (at != null) lines[row.substring(0, cut)] = at;
    }
    return lines;
  }

  static bool _lower(Map<String, int> lines, String id, int at) {
    final known = lines[id];
    if (known != null && known <= at) return false;
    lines[id] = at;
    return true;
  }

  /// The line for [conversationId] in epoch milliseconds, or null when this
  /// phone has opened no sealed message there.
  Future<int?> since(String userId, String conversationId) async {
    if (userId.isEmpty || conversationId.isEmpty) return null;
    return (await _load(userId))[conversationId];
  }

  /// A sealed message sent at [createdAt] (the server's ISO time) opened.
  Future<void> note(
    String userId,
    String conversationId,
    String createdAt,
  ) async {
    if (userId.isEmpty || conversationId.isEmpty) return;
    final at = DateTime.tryParse(createdAt)?.millisecondsSinceEpoch;
    if (at == null) return;
    if (!_lower(await _load(userId), conversationId, at)) return;
    changes.value++;
    await _write(userId);
  }

  // A page of fifty messages moves the line many times in one breath; the
  // writes that pile up behind the one in flight become a single write.
  Future<void> _write(String userId) async {
    if (!_writing.add(userId)) {
      _again.add(userId);
      return;
    }
    try {
      do {
        _again.remove(userId);
        final prefs = await SharedPreferences.getInstance();
        final key = '$_prefix$userId';
        final lines = _memory[userId] ?? <String, int>{};
        // Never raised by a write: what is stored is kept where it is older.
        _parse(
          prefs.getStringList(key),
        ).forEach((id, at) => _lower(lines, id, at));
        await prefs.setStringList(key, [
          for (final line in lines.entries) '${line.key} ${line.value}',
        ]);
      } while (_again.contains(userId));
    } catch (_) {
      // Held in memory for this run; written with the next move.
    } finally {
      _writing.remove(userId);
    }
  }
}

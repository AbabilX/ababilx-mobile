import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Seat {
  _Seat(this.since, this.seen);

  /// The newest key version that existed before this member did, as far as
  /// this phone saw: 0 = here from the start, -1 = met, version not known yet.
  int since;

  /// The user has been shown that this member reads the chat.
  bool seen;
}

/// This phone's own record of who each group's keys are sealed to.
///
/// A group's roster comes from the server (`e2ee-members`) and nothing on the
/// phone can check it: one extra `chat_conversation_members` row is sealed
/// the next key. Two things are still the phone's to decide.
///
/// **Old keys.** The backfill hands a key this phone holds to whoever the
/// server says lost it. A row added with a join date in the past would be
/// handed every old key, so the whole history. A member this phone first met
/// at key version N is never handed version N or older by this phone,
/// whatever the server lists. Someone here from the start still gets theirs
/// back after starting fresh.
///
/// **Being told.** A member who appears is listed until the user has looked
/// ([unseen]), from this record and not from the server's "X added Y" line,
/// which the same database write can leave out.
///
/// Trust on first use: the first roster seen is taken as it is. Written only
/// by the app; the notification isolate keeps no record.
class GroupRosterPins {
  const GroupRosterPins();

  static const _prefix = 'chat_group_roster_v1:';
  static final _memory = <String, Map<String, _Seat>>{};

  /// Bumped on every change, for whatever is drawing the notice.
  static final changes = ValueNotifier<int>(0);

  String _key(String userId, String conversationId) =>
      '$_prefix$userId:$conversationId';

  /// The record, or null when this phone has none for the conversation.
  Future<Map<String, _Seat>?> _load(String userId, String conversationId) async {
    final key = _key(userId, conversationId);
    final held = _memory[key];
    if (held != null) return held;
    try {
      final prefs = await SharedPreferences.getInstance();
      final rows = prefs.getStringList(key);
      if (rows == null) return null;
      final seats = <String, _Seat>{};
      for (final row in rows) {
        final part = row.split(' ');
        if (part.length != 3) continue;
        seats[part[0]] = _Seat(int.tryParse(part[1]) ?? -1, part[2] == '1');
      }
      return _memory[key] = seats;
    } catch (_) {
      // Unreadable storage is not the server's doing: no record, no bound.
      return null;
    }
  }

  Future<void> _save(
    String userId,
    String conversationId,
    Map<String, _Seat> seats,
  ) async {
    final key = _key(userId, conversationId);
    _memory[key] = seats;
    changes.value++;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(key, [
        for (final s in seats.entries)
          '${s.key} ${s.value.since} ${s.value.seen ? 1 : 0}',
      ]);
    } catch (_) {
      // Held in memory for this run.
    }
  }

  Future<bool> known(String userId, String conversationId) async =>
      await _load(userId, conversationId) != null;

  /// Records [memberIds] as the roster now. Pass [before], the newest key
  /// version older than the one just sealed to them, when it is known.
  Future<void> observe(
    String userId,
    String conversationId,
    Iterable<String> memberIds, {
    int? before,
  }) async {
    if (userId.isEmpty || conversationId.isEmpty) return;
    final ids = {
      for (final id in memberIds)
        if (id.isNotEmpty && id != userId) id,
    };
    final seats = await _load(userId, conversationId);
    if (seats == null) {
      return _save(userId, conversationId, {
        for (final id in ids) id: _Seat(0, true),
      });
    }
    final before0 = seats.length;
    // Someone who left is forgotten: added again, they are new again.
    seats.removeWhere((id, _) => !ids.contains(id));
    var moved = seats.length != before0;
    for (final id in ids) {
      final seat = seats[id];
      if (seat == null) {
        seats[id] = _Seat(before ?? -1, false);
        moved = true;
      } else if (seat.since < 0 && before != null) {
        seat.since = before;
        moved = true;
      }
    }
    if (moved) await _save(userId, conversationId, seats);
  }

  /// Whether key [version] may be handed to [memberId]. [newest] is the
  /// newest version this phone knows of: a member met only now is older than
  /// none of them.
  Future<bool> mayHandKey(
    String userId,
    String conversationId,
    String memberId, {
    required int version,
    required int newest,
  }) async {
    final seats = await _load(userId, conversationId);
    if (seats == null) return true;
    final seat = seats[memberId];
    if (seat != null && seat.since >= 0) return version > seat.since;
    seats[memberId] = _Seat(newest, seat?.seen ?? false);
    await _save(userId, conversationId, seats);
    return false;
  }

  /// Members who appeared since the user last looked.
  Future<List<String>> unseen(String userId, String conversationId) async {
    final seats = await _load(userId, conversationId);
    return [
      for (final s in (seats ?? const <String, _Seat>{}).entries)
        if (!s.value.seen) s.key,
    ];
  }

  Future<void> markSeen(String userId, String conversationId) async {
    final seats = await _load(userId, conversationId);
    if (seats == null || seats.values.every((s) => s.seen)) return;
    for (final seat in seats.values) {
      seat.seen = true;
    }
    await _save(userId, conversationId, seats);
  }

  /// This phone's own user just added [memberId]: nothing to be told. Only
  /// where a record exists; a first roster takes everyone as seen anyway.
  Future<void> expect(
    String userId,
    String conversationId,
    String memberId,
  ) async {
    final seats = await _load(userId, conversationId);
    if (seats == null || memberId.isEmpty || memberId == userId) return;
    final seat = seats[memberId];
    if (seat?.seen ?? false) return;
    seats[memberId] = _Seat(seat?.since ?? -1, true);
    await _save(userId, conversationId, seats);
  }
}

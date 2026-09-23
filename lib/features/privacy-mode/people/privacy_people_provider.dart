import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../auth/providers/auth_provider.dart';
import 'privacy_person.dart';

/// This account's per-person privacy choices (server migration 0153), keyed
/// by user id. Only "always" and "never" are held; anyone absent follows the
/// switch in `privacyModeProvider`.
///
/// Kept on the device too, for the same reason as the switch: a phone that
/// starts offline must know it is private with someone before its first photo
/// to them goes into the outbox.
///
/// Every local write (a choice made here, or one from another device) stamps
/// that person with a fresh [_clock] value. A server reply lands for a person
/// only if nothing newer was written for them since it was asked for, so a
/// slow fetch or PUT can never put back a choice the user has since changed.
/// [_session] does the same across sign-in and sign-out.
class PrivacyPeopleNotifier extends Notifier<Map<String, PrivacyPerson>> {
  static const _prefsKey = 'privacy_people_v1';
  static const _resolveTimeout = Duration(seconds: 3);

  Future<void>? _loading;
  int _session = 0;
  int _clock = 0;
  final _writtenAt = <String, int>{};

  @override
  Map<String, PrivacyPerson> build() {
    final session = ++_session;
    _writtenAt.clear();
    if (!ref.watch(isAuthenticatedProvider)) {
      _loading = null;
      _forget();
      return const {};
    }
    _loading = _load(session);
    return const {};
  }

  /// The choices as they stand now, after (briefly) waiting for the first
  /// load so a cold start does not answer with an empty map.
  Future<Map<String, PrivacyPerson>> resolve() async {
    final loading = _loading;
    if (loading != null) {
      try {
        await loading.timeout(_resolveTimeout);
      } catch (_) {}
    }
    return state;
  }

  PrivacyPersonMode modeFor(String userId) =>
      state[userId]?.mode ?? PrivacyPersonMode.follow;

  /// Re-reads the list, e.g. when the settings screen opens — the only way a
  /// choice made on another device gets its name and picture.
  Future<void> refresh() => _fetch(_session);

  /// Stores [person]'s mode. Returns false when the server refused; the
  /// previous choice is put back.
  Future<bool> set(PrivacyPerson person) async {
    final session = _session;
    final id = person.userId;
    final previous = state[id];
    final stamp = _write(id, _held(person));
    try {
      await ref
          .read(apiClientProvider)
          .put(
            '${ApiConstants.mePrivacyPeople}/$id',
            data: {'mode': person.mode.wire},
          );
      return true;
    } catch (_) {
      if (_owns(session, id, stamp)) _write(id, previous);
      return false;
    }
  }

  /// Another device of this account changed a choice (`chat.privacy_person`).
  void applyRemote(String userId, PrivacyPersonMode mode) {
    final known = state[userId];
    _write(
      userId,
      _held(known?.withMode(mode) ?? PrivacyPerson(userId: userId, mode: mode)),
    );
  }

  static PrivacyPerson? _held(PrivacyPerson p) =>
      p.mode == PrivacyPersonMode.follow ? null : p;

  int _write(String id, PrivacyPerson? person) {
    final stamp = ++_clock;
    _writtenAt[id] = stamp;
    final next = {...state};
    person == null ? next.remove(id) : next[id] = person;
    state = next;
    unawaited(_persist(_session));
    return stamp;
  }

  bool _owns(int session, String id, int stamp) =>
      session == _session && _writtenAt[id] == stamp;

  Future<void> _load(int session) async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString(_prefsKey);
      if (raw != null && session == _session) _merge(_decode(raw), 0);
    } catch (_) {}
    await _fetch(session);
  }

  Future<void> _fetch(int session) async {
    final asked = _clock;
    try {
      final res = await ref
          .read(apiClientProvider)
          .get(ApiConstants.mePrivacyPeople);
      if (session != _session) return;
      final data = res.data is Map ? (res.data as Map)['data'] : null;
      final rows = data is Map ? data['people'] : null;
      _merge([
        if (rows is List)
          for (final row in rows) ?PrivacyPerson.fromJson(row),
      ], asked);
      await _persist(session);
    } catch (_) {}
  }

  /// Replaces the map with [people], except for anyone written locally
  /// after [asked] — their current value is newer than this answer.
  void _merge(List<PrivacyPerson> people, int asked) {
    final next = {for (final p in people) p.userId: p};
    _writtenAt.forEach((id, stamp) {
      if (stamp <= asked) return;
      final mine = state[id];
      mine == null ? next.remove(id) : next[id] = mine;
    });
    state = next;
  }

  Future<void> _persist(int session) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (session != _session) return;
      await prefs.setString(
        _prefsKey,
        jsonEncode([for (final p in state.values) p.toJson()]),
      );
    } catch (_) {}
  }

  Future<void> _forget() async {
    try {
      await (await SharedPreferences.getInstance()).remove(_prefsKey);
    } catch (_) {}
  }

  static List<PrivacyPerson> _decode(String raw) {
    final list = jsonDecode(raw);
    return [
      if (list is List)
        for (final row in list) ?PrivacyPerson.fromJson(row),
    ];
  }
}

final privacyPeopleProvider =
    NotifierProvider<PrivacyPeopleNotifier, Map<String, PrivacyPerson>>(
      PrivacyPeopleNotifier.new,
    );

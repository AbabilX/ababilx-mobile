import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// The live history links this phone answers (server 0175), per account:
/// link id → the transfer key it sealed to that computer's history key, and
/// the computer's name. Secure storage: the key opens the signals of that
/// link, and must not sit in a plain file.
class LiveLink {
  const LiveLink({required this.id, required this.key, required this.device});

  final String id;
  final List<int> key;
  final String device;
}

class LiveLinks {
  LiveLinks([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  String _name(String userId) => 'history_live_links_v1:$userId';

  Future<Map<String, LiveLink>> all(String userId) async {
    try {
      final raw = await _storage.read(key: _name(userId));
      if (raw == null || raw.isEmpty) return {};
      final map = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      return {
        for (final entry in map.entries)
          entry.key: LiveLink(
            id: entry.key,
            key: base64Decode((entry.value as Map)['k'] as String),
            device: (entry.value as Map)['d'] as String? ?? '',
          ),
      };
    } catch (_) {
      return {};
    }
  }

  Future<LiveLink?> read(String userId, String id) async =>
      (await all(userId))[id];

  Future<void> save(String userId, LiveLink link) async {
    final links = await all(userId);
    links[link.id] = link;
    // A computer linked again replaces its old link server-side; keep a
    // bounded few here so a phone that linked many browsers stays small.
    final kept = links.values.toList().reversed.take(8).toList();
    await _storage.write(
      key: _name(userId),
      value: jsonEncode({
        for (final l in kept) l.id: {'k': base64Encode(l.key), 'd': l.device},
      }),
    );
  }

  Future<void> forget(String userId, String id) async {
    final links = await all(userId)
      ..remove(id);
    await _storage.write(
      key: _name(userId),
      value: jsonEncode({
        for (final l in links.values)
          l.id: {'k': base64Encode(l.key), 'd': l.device},
      }),
    );
  }
}

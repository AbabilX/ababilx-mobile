import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';

/// The account backup key (server 0163): fetched once, then kept in the
/// Keystore-backed secure storage so the daily run works offline.
///
/// Stored per user id, so a second account on the phone can never pick up the
/// first one's key, and dropped with everything else by
/// `clearAllPrivateData` on a confirmed account switch. Keeping it on the
/// phone costs nothing the phone did not already have: the backup file is on
/// the same phone, and the account's session can fetch the key anyway.
class BackupKeyStore {
  BackupKeyStore(this._client, [this._storage = const FlutterSecureStorage()]);

  final ApiClient _client;
  final FlutterSecureStorage _storage;
  final _memory = <String, List<int>>{};

  static String _slot(String userId) => 'local_backup_key_v1_$userId';

  /// Memory, then secure storage, then the server. Throws when none answers.
  Future<List<int>> keyFor(String userId) async {
    final stored = await storedFor(userId);
    if (stored != null) return stored;
    final res = await _client.get<dynamic>(ApiConstants.meBackupKey);
    final data = unwrapApiData<Map<String, dynamic>>(res);
    // The server answers for the session's account. A key for anybody else
    // (a token swapped under us mid-request) must not be cached as ours.
    if (data['user_id'] != userId) {
      throw StateError('backup key answered for another account');
    }
    final key = base64Url.decode(base64Url.normalize(data['key'] as String));
    if (key.length != 32) throw StateError('backup key has the wrong length');
    _memory[userId] = key;
    await _storage.write(key: _slot(userId), value: base64Url.encode(key));
    return key;
  }

  /// Never touches the network — for reading restored messages, which must
  /// work offline and must not fire a request per bubble.
  Future<List<int>?> storedFor(String userId) async {
    if (userId.isEmpty) return null;
    final cached = _memory[userId];
    if (cached != null) return cached;
    try {
      final raw = await _storage.read(key: _slot(userId));
      if (raw == null) return null;
      final key = base64Url.decode(raw);
      if (key.length != 32) return null;
      return _memory[userId] = key;
    } catch (_) {
      return null;
    }
  }
}

final backupKeyStoreProvider = Provider<BackupKeyStore>(
  (ref) => BackupKeyStore(ref.watch(apiClientProvider)),
);

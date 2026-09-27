import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/backup_key_store.dart';
import '../format/backup_crypto.dart';

/// The readable text of messages that came back from a local backup.
///
/// A restore after "start fresh" brings back ciphertext nobody's key opens any
/// more, plus the plaintext the backup carried. The row stays exactly as the
/// server has it — so a later page from the server overwrites nothing that
/// matters — and the text lives here, sealed under a key derived from the
/// account backup key, in its own table of the same SQLCipher database. The
/// vault asks here only after its own key has failed (`restoredBodyLookup`).
///
/// Android only, like the SQLCipher store; elsewhere every call is a no-op.
class RestoredBodyStore {
  RestoredBodyStore(this._keys);

  final BackupKeyStore _keys;
  static const _channel = MethodChannel('com.ababilx.app/chat_store');
  final _sealKeys = <String, SecretKey>{};

  Future<SecretKey?> _key(String userId) async {
    final cached = _sealKeys[userId];
    if (cached != null) return cached;
    final account = await _keys.storedFor(userId);
    if (account == null) return null;
    return _sealKeys[userId] = await BackupCrypto.restoredKey(account);
  }

  Future<void> putAll(String userId, Map<String, String> bodies) async {
    if (!Platform.isAndroid || bodies.isEmpty) return;
    final key = await _key(userId);
    if (key == null) return;
    final rows = <String, String>{};
    for (final entry in bodies.entries) {
      final sealed = await BackupCrypto.seal(
        key,
        BackupCrypto.restoredAad(entry.key),
        utf8.encode(entry.value),
      );
      rows[entry.key] = base64.encode(sealed);
    }
    await _channel.invokeMethod<void>('putRestored', {'rows': rows});
  }

  Future<String?> lookup(String messageId, String userId) async {
    if (!Platform.isAndroid || messageId.isEmpty) return null;
    try {
      final sealed = await _channel.invokeMethod<String>('restored', {
        'messageId': messageId,
      });
      if (sealed == null) return null;
      final key = await _key(userId);
      if (key == null) return null;
      final plain = await BackupCrypto.open(
        key,
        BackupCrypto.restoredAad(messageId),
        base64.decode(sealed),
      );
      return utf8.decode(plain);
    } catch (_) {
      return null;
    }
  }
}

final restoredBodyStoreProvider = Provider<RestoredBodyStore>(
  (ref) => RestoredBodyStore(ref.watch(backupKeyStoreProvider)),
);

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  static const _presentKey = 'restored_bodies_present_v1:';
  final _sealKeys = <String, SecretKey>{};
  final _present = <String, bool>{};

  /// Whether a restore ever wrote text for [userId] on this phone. The vault
  /// reads restored text before asking the server only when it did, so an
  /// account that never restored pays nothing for it. Remembered in memory;
  /// set again by the first restored body found, which covers restores made
  /// before this flag existed.
  Future<bool> present(String userId) async {
    if (!Platform.isAndroid || userId.isEmpty) return false;
    final known = _present[userId];
    if (known != null) return known;
    try {
      final prefs = await SharedPreferences.getInstance();
      return _present[userId] = prefs.getBool('$_presentKey$userId') ?? false;
    } catch (_) {
      return _present[userId] = false;
    }
  }

  Future<void> _markPresent(String userId) async {
    if (_present[userId] == true) return;
    _present[userId] = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('$_presentKey$userId', true);
    } catch (_) {}
  }

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
    await _markPresent(userId);
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
      unawaited(_markPresent(userId));
      return utf8.decode(plain);
    } catch (_) {
      return null;
    }
  }
}

final restoredBodyStoreProvider = Provider<RestoredBodyStore>(
  (ref) => RestoredBodyStore(ref.watch(backupKeyStoreProvider)),
);

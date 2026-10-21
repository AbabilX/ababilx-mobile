import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:cryptography/dart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// The backup PIN (user's call, 2026-10-21): the PIN ALONE opens a backup,
/// so a reinstalled phone needs nothing from the server or anyone else.
///
/// The file key is PBKDF2-HMAC-SHA256 over the PIN, salted with the account
/// id, so the same PIN on two accounts gives two keys and a restore needs only
/// the PIN and the file's own header. Only the derived key is kept here, in
/// the Keystore-backed secure storage, so the scheduled run never asks; the
/// PIN itself is never stored.
///
/// The PIN is 6 to 10 hex characters (0-9, a-f), stored lowercase so the
/// keyboard's case never changes the key. Plain digits are hex too, so a
/// 6-digit PIN set earlier still opens its backups.
///
/// **Honest limit, accepted by the user:** a 6-digit PIN is 10^6 guesses.
/// Anyone holding the backup file can try them all offline; the iteration
/// count and a longer PIN make that slower, not impossible.
///
/// Every string and number here is part of the file format — changing one
/// makes every PIN backup unopenable.
class BackupPinStore {
  BackupPinStore([this._storage = const FlutterSecureStorage()]);

  static const saltPrefix = 'ababilx-backup-pin-v1:';
  static const iterations = 300000;
  static const minLength = 6;
  static const maxLength = 10;

  final FlutterSecureStorage _storage;
  final _memory = <String, List<int>>{};

  static String _slot(String userId) => 'local_backup_pin_key_v1_$userId';

  /// Lowercase, no spaces: the form the key is derived from.
  static String normalize(String pin) => pin.trim().toLowerCase();

  static bool validPin(String pin) =>
      RegExp('^[0-9a-f]{$minLength,$maxLength}\$').hasMatch(normalize(pin));

  /// The stored key, or null when no PIN was set on this install.
  Future<List<int>?> keyFor(String userId) async {
    if (userId.isEmpty) return null;
    final cached = _memory[userId];
    if (cached != null) return cached;
    try {
      final raw = await _storage.read(key: _slot(userId));
      if (raw == null) return null;
      final key = base64Url.decode(raw);
      return key.length == 32 ? _memory[userId] = key : null;
    } catch (_) {
      return null;
    }
  }

  Future<bool> has(String userId) async => await keyFor(userId) != null;

  /// Seconds of work, off the UI isolate. Does not store anything.
  static Future<List<int>> derive(
    String userId,
    String pin, {
    int rounds = iterations,
  }) => Isolate.run(() async {
    final key =
        await DartPbkdf2(
          macAlgorithm: DartHmac(const DartSha256()),
          iterations: rounds,
          bits: 256,
        ).deriveKeyFromPassword(
          password: normalize(pin),
          nonce: utf8.encode('$saltPrefix$userId'),
        );
    return Uint8List.fromList(await key.extractBytes());
  });

  Future<void> save(String userId, List<int> key) async {
    _memory[userId] = key;
    await _storage.write(key: _slot(userId), value: base64Url.encode(key));
  }

  /// Sets the PIN on this install: derived, then kept.
  Future<List<int>> setPin(String userId, String pin) async {
    final key = await derive(userId, pin);
    await save(userId, key);
    return key;
  }
}

final backupPinStoreProvider = Provider<BackupPinStore>(
  (_) => BackupPinStore(),
);

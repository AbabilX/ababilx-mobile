import 'dart:convert';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/dart.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// The per-chat passwords, as PBKDF2-HMAC-SHA256 hashes in secure storage.
/// Nothing that could open a chat is ever stored in the clear, and the hash
/// sits behind the Android Keystore like the session token does.
///
/// A person picks this password, so it is guessable and the hash is
/// stretched; the stored form names its own parameters so a later change of
/// iteration count still verifies old ones. Account-switch wipes every
/// secure-storage key, these included.
abstract final class ChatLockSecrets {
  static const _storage = FlutterSecureStorage();
  static const _prefix = 'chat_lock_pw_v1_';
  static const _iterations = 100000;

  static Future<void> setPassword(
    String conversationId,
    String password,
  ) async {
    final salt = _randomBytes(16);
    final hash = await _derive(password, salt, _iterations);
    await _storage.write(
      key: '$_prefix$conversationId',
      value: 'v1:$_iterations:${base64Encode(salt)}:${base64Encode(hash)}',
    );
  }

  static Future<bool> verify(String conversationId, String password) async {
    final stored = await _storage.read(key: '$_prefix$conversationId');
    final parts = stored?.split(':') ?? const [];
    if (parts.length != 4 || parts[0] != 'v1') return false;
    final iterations = int.tryParse(parts[1]) ?? 0;
    if (iterations <= 0) return false;
    try {
      final salt = base64Decode(parts[2]);
      final expected = base64Decode(parts[3]);
      final actual = await _derive(password, salt, iterations);
      return _sameBytes(actual, expected);
    } on FormatException {
      return false;
    }
  }

  static Future<void> remove(String conversationId) =>
      _storage.delete(key: '$_prefix$conversationId');

  /// Stretching takes a noticeable fraction of a second in Dart, so it runs
  /// off the UI isolate — the unlock screen keeps animating meanwhile.
  static Future<Uint8List> _derive(
    String password,
    List<int> salt,
    int iterations,
  ) => Isolate.run(() async {
    final key = await DartPbkdf2(
      macAlgorithm: DartHmac(const DartSha256()),
      iterations: iterations,
      bits: 256,
    ).deriveKeyFromPassword(password: password, nonce: salt);
    return Uint8List.fromList(await key.extractBytes());
  });

  static Uint8List _randomBytes(int length) {
    final random = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(length, (_) => random.nextInt(256)),
    );
  }

  /// Constant time: how far a wrong guess matched must not show in timing.
  static bool _sameBytes(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }
}

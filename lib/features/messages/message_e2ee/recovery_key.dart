import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';

/// The recovery code: 256 bits of randomness, generated on the device, shown
/// once, and never sent to AbabilX.
///
/// It is what lets end-to-end encryption survive a new phone. The identity's
/// private key is stored on the server wrapped by a key derived from this code,
/// so what the server holds is ciphertext against a 2^256 keyspace.
///
/// **Every byte here has a twin in `lib/chat-e2ee/recovery-key.ts`.** The info
/// string, the salt handling, the AAD and the base64url flavour must match, or
/// a code written down on a phone opens nothing in a browser — a lost history
/// with no error to point at. `test/features/messages/recovery_key_test.dart`
/// pins the derivation against the same vector the web test uses.
class RecoveryVault {
  const RecoveryVault({
    required this.ciphertext,
    required this.nonce,
    required this.salt,
    required this.version,
  });

  factory RecoveryVault.fromJson(Map<String, dynamic> json) {
    final wrapped = Map<String, dynamic>.from(json['wrapped_key'] as Map);
    return RecoveryVault(
      ciphertext: wrapped['ciphertext'] as String,
      nonce: wrapped['nonce'] as String,
      salt: json['salt'] as String,
      version: (json['version'] as num).toInt(),
    );
  }

  final String ciphertext;
  final String nonce;
  final String salt;
  final int version;

  Map<String, dynamic> toJson() => {
    'wrapped_key': {'ciphertext': ciphertext, 'nonce': nonce},
    'salt': salt,
    'version': version,
  };
}

class RecoveryKey {
  static const _info = 'ababilx-recovery-key-v1';
  static const _aad = 'ababilx-recovery-vault-v1';
  static const version = 1;
  static const _codeBytes = 32;

  static final _aes = AesGcm.with256bits();

  /// Mints a code. `Random.secure()` is the only acceptable source: a
  /// predictable code is a readable account.
  static List<int> generateCode() {
    final random = Random.secure();
    return List<int>.generate(_codeBytes, (_) => random.nextInt(256));
  }

  /// Formats it the way it is shown and typed: hex in groups of four.
  static String format(List<int> bytes) {
    final hex = bytes
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join()
        .toUpperCase();
    final groups = <String>[];
    for (var i = 0; i < hex.length; i += 4) {
      groups.add(hex.substring(i, i + 4));
    }
    return groups.join('-');
  }

  /// Reads a code back, ignoring spacing and case. People retype these from
  /// paper and paste them from password managers; rejecting a lowercase paste
  /// would be a lockout caused by formatting.
  static List<int>? parse(String input) {
    final hex = input.replaceAll(RegExp(r'[^0-9a-fA-F]'), '').toLowerCase();
    if (hex.length != _codeBytes * 2) return null;
    return [
      for (var i = 0; i < hex.length; i += 2)
        int.parse(hex.substring(i, i + 2), radix: 16),
    ];
  }

  /// HKDF, not PBKDF2: the input already carries 256 bits of entropy, and
  /// stretching only buys anything against a guessable secret.
  static Future<SecretKey> deriveKey(List<int> code, List<int> salt) =>
      Hkdf(hmac: Hmac.sha256(), outputLength: 32).deriveKey(
        secretKey: SecretKey(code),
        nonce: salt,
        info: utf8.encode(_info),
      );

  static Future<RecoveryVault> wrap(
    Map<String, dynamic> privateJwk,
    List<int> code,
  ) async {
    final random = Random.secure();
    final salt = List<int>.generate(32, (_) => random.nextInt(256));
    final nonce = List<int>.generate(12, (_) => random.nextInt(256));
    final box = await _aes.encrypt(
      utf8.encode(jsonEncode(privateJwk)),
      secretKey: await deriveKey(code, salt),
      nonce: nonce,
      aad: utf8.encode(_aad),
    );
    return RecoveryVault(
      ciphertext: _b64([...box.cipherText, ...box.mac.bytes]),
      nonce: _b64(nonce),
      salt: _b64(salt),
      version: version,
    );
  }

  /// Opens a stored vault. A wrong code and a corrupt blob fail the same
  /// AES-GCM tag check, and the difference is of no use to the person holding
  /// the code, so both surface as "wrong code".
  static Future<Map<String, dynamic>> unwrap(
    RecoveryVault vault,
    List<int> code,
  ) async {
    final all = _bytes(vault.ciphertext);
    final clear = await _aes.decrypt(
      SecretBox(
        all.sublist(0, all.length - 16),
        nonce: _bytes(vault.nonce),
        mac: Mac(all.sublist(all.length - 16)),
      ),
      secretKey: await deriveKey(code, _bytes(vault.salt)),
      aad: utf8.encode(_aad),
    );
    return Map<String, dynamic>.from(
      jsonDecode(utf8.decode(clear)) as Map,
    );
  }

  static String _b64(List<int> bytes) =>
      base64Url.encode(bytes).replaceAll('=', '');

  static List<int> _bytes(String value) =>
      base64Url.decode(base64Url.normalize(value));
}

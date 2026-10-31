import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// Every key a local backup uses, derived from the account backup key (server
/// migration 0163) with HKDF-SHA256 and a distinct `info` per purpose, so the
/// file key, the account check and the restored-body key are never the same
/// bytes.
///
/// **Rooted in the account, not the E2EE identity** — the opposite of
/// `ArchiveKey`, and on purpose. The archive dies with "start fresh"; this file
/// is what a person who lost the recovery code restores from, so its key must
/// outlive the identity. What it costs is written in the migration: the server
/// holds the key, the phone holds the file, and both together read it.
///
/// Every string here is part of the file format. Changing one makes every
/// backup already written unopenable, with no error that names the cause —
/// `backup_format_test.dart` pins them.
abstract final class BackupCrypto {
  static const fileInfo = 'ababilx-local-backup-file-v1';
  static const checkInfo = 'ababilx-local-backup-check-v1';
  static const restoredInfo = 'ababilx-restored-body-v1';
  static const recordAadPrefix = 'ababilx-local-backup-v1';
  static const restoredAadPrefix = 'ababilx-restored-v1';

  static const keyBytes = 32;
  static const saltBytes = 32;
  static const checkBytes = 16;
  static const nonceBytes = 12;
  static const tagBytes = 16;

  static final _aes = AesGcm.with256bits();
  static final _hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: keyBytes);

  /// The key one backup file is sealed with. A fresh salt per file means two
  /// files never share a key even though they share the account key.
  static Future<SecretKey> fileKey(List<int> accountKey, List<int> salt) =>
      _derive(accountKey, salt, fileInfo);

  /// 16 bytes stored in the clear header, so a restore can tell "this file
  /// belongs to another account" apart from "this file is damaged" before it
  /// decrypts anything. HMAC over the file's salt under a derived key: it
  /// reveals nothing about the account key and differs per file.
  static Future<List<int>> keyCheck(
    List<int> accountKey,
    List<int> salt,
  ) async {
    final checkKey = await _derive(accountKey, noSalt, checkInfo);
    final mac = await Hmac.sha256().calculateMac(salt, secretKey: checkKey);
    return mac.bytes.sublist(0, checkBytes);
  }

  /// Seals the restored plaintext of a message on this phone (see
  /// `RestoredBodyStore`), so the local store keeps no readable body of an
  /// encrypted message — the rule `AndroidChatMessageStore` already follows.
  static Future<SecretKey> restoredKey(List<int> accountKey) =>
      _derive(accountKey, noSalt, restoredInfo);

  /// RFC 5869's "no salt": HashLen zero bytes, never an EMPTY list. HKDF keys
  /// an HMAC with the salt, and on a phone `cryptography_flutter` runs that
  /// HMAC in Java, where `SecretKeySpec` refuses an empty key ("Empty key") —
  /// every backup failed on the device while the pure-Dart tests passed. HMAC
  /// zero-pads a short key, so this is byte-identical to an empty salt.
  static final List<int> noSalt = List<int>.filled(32, 0, growable: false);

  /// Binds a record to its position AND to the exact header it follows, so
  /// dropping, reordering or moving records between files fails the tag, and so
  /// does editing the clear header (say, swapping the account id).
  static List<int> recordAad(String headerDigest, int index) =>
      utf8.encode('$recordAadPrefix:$headerDigest:$index');

  static List<int> restoredAad(String messageId) =>
      utf8.encode('$restoredAadPrefix:$messageId');

  /// `nonce | ciphertext | tag`, one contiguous buffer.
  static Future<Uint8List> seal(
    SecretKey key,
    List<int> aad,
    List<int> plaintext,
  ) async {
    final nonce = randomBytes(nonceBytes);
    final box = await _aes.encrypt(
      plaintext,
      secretKey: key,
      nonce: nonce,
      aad: aad,
    );
    // Copied into place: a spread made a boxed int list of the whole record.
    final cipher = box.cipherText;
    final tag = box.mac.bytes;
    final end = nonce.length + cipher.length;
    return Uint8List(end + tag.length)
      ..setRange(0, nonce.length, nonce)
      ..setRange(nonce.length, end, cipher)
      ..setRange(end, end + tag.length, tag);
  }

  /// Throws [SecretBoxAuthenticationError] on a wrong key, a wrong position or
  /// a changed byte — never a partial plaintext.
  static Future<List<int>> open(
    SecretKey key,
    List<int> aad,
    List<int> sealed,
  ) {
    if (sealed.length < nonceBytes + tagBytes) {
      throw SecretBoxAuthenticationError();
    }
    return _aes.decrypt(
      SecretBox(
        sealed.sublist(nonceBytes, sealed.length - tagBytes),
        nonce: sealed.sublist(0, nonceBytes),
        mac: Mac(sealed.sublist(sealed.length - tagBytes)),
      ),
      secretKey: key,
      aad: aad,
    );
  }

  static Uint8List randomBytes(int length) {
    final random = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(length, (_) => random.nextInt(256)),
    );
  }

  static Future<SecretKey> _derive(
    List<int> accountKey,
    List<int> salt,
    String info,
  ) {
    if (accountKey.length != keyBytes) {
      throw ArgumentError('account backup key must be $keyBytes bytes');
    }
    if (salt.isEmpty) throw ArgumentError('HKDF salt must not be empty');
    return _hkdf.deriveKey(
      secretKey: SecretKey(accountKey),
      nonce: salt,
      info: utf8.encode(info),
    );
  }
}

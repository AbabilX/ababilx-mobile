import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Safety numbers — the only thing standing between AbabilX and every message.
///
/// A DM key is wrapped against a public key the server hands us, and nothing in
/// the protocol proves that key is really the other person's. A malicious or
/// compromised server can hand us its own and read the conversation forever.
/// No amount of cryptography detects that from the inside; two people comparing
/// the same digits out of band is what detects it.
///
/// The derivation is Signal's numeric fingerprint, kept exactly: 5200 rounds of
/// SHA-512 over the identity key, so grinding a key whose fingerprint collides
/// costs 5200x what a single hash would, then six five-byte chunks reduced
/// mod 100000 to give 30 digits per person.
///
/// The digits MUST come out identical on mobile, web and desktop, or two people
/// comparing them read unrelated numbers and the check is worse than useless —
/// it would teach them to expect a mismatch. `safety_number_test.dart` and the
/// web client's `safety-number.test.mjs` pin the same vector on both sides;
/// change one and the other fails.
class SafetyIdentity {
  const SafetyIdentity({required this.userId, required this.publicKey});

  final String userId;
  final Map<String, dynamic> publicKey;
}

const int _iterations = 5200;
const int _version = 0;
const List<int> _chunkOffsets = [0, 5, 10, 15, 20, 25];

Uint8List _decodeCoordinate(String value) {
  final padded = value.padRight((value.length + 3) ~/ 4 * 4, '=');
  return base64Url.decode(padded);
}

/// The identity key as an uncompressed P-256 point, `0x04 || X || Y`.
///
/// The JWK itself is not usable here: its key order and whitespace are free, so
/// a fingerprint taken over the encoded JSON could differ between two clients
/// that agree on the key.
Uint8List _identityKeyBytes(Map<String, dynamic> publicKey) {
  final x = _decodeCoordinate(publicKey['x'] as String? ?? '');
  final y = _decodeCoordinate(publicKey['y'] as String? ?? '');
  if (x.length != 32 || y.length != 32) {
    throw ArgumentError('This identity key cannot produce a safety number');
  }
  return Uint8List(65)
    ..[0] = 0x04
    ..setRange(1, 33, x)
    ..setRange(33, 65, y);
}

/// One person's 30 digits: their identity key bound to their user id, so a key
/// lifted from one account cannot be replayed under another.
String identityFingerprint(SafetyIdentity identity) {
  final key = _identityKeyBytes(identity.publicKey);
  final seed = <int>[
    (_version >> 8) & 0xff,
    _version & 0xff,
    ...key,
    ...utf8.encode(identity.userId),
    ...key,
  ];
  var hash = Uint8List.fromList(sha512.convert(seed).bytes);
  // Every later round hashes the same 64 + 65 bytes, so the buffer is built
  // once and only its first half is rewritten. 5200 fresh concatenations would
  // dominate the cost of the hashing they exist to feed.
  final buffer = Uint8List(hash.length + key.length)
    ..setRange(hash.length, hash.length + key.length, key);
  for (var round = 1; round < _iterations; round += 1) {
    buffer.setRange(0, hash.length, hash);
    hash = Uint8List.fromList(sha512.convert(buffer).bytes);
  }

  final digits = StringBuffer();
  for (final offset in _chunkOffsets) {
    // Five big-endian bytes is at most 2^40, comfortably inside a Dart int.
    var chunk = 0;
    for (var i = offset; i < offset + 5; i += 1) {
      chunk = chunk * 256 + hash[i];
    }
    digits.write((chunk % 100000).toString().padLeft(5, '0'));
  }
  return digits.toString();
}

/// The 60 digits both people see. Sorted, so it does not matter which side is
/// asking — two phones held next to each other must show the same string.
String safetyNumber(SafetyIdentity mine, SafetyIdentity theirs) {
  final ours = identityFingerprint(mine);
  final peer = identityFingerprint(theirs);
  return ours.compareTo(peer) <= 0 ? '$ours$peer' : '$peer$ours';
}

/// Groups of five, the way they are meant to be read aloud.
List<String> safetyNumberGroups(String digits) => [
  for (var i = 0; i < digits.length; i += 5)
    digits.substring(i, i + 5 > digits.length ? digits.length : i + 5),
];

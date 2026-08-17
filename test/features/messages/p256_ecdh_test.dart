import 'package:ababilx/features/messages/message_e2ee/p256_ecdh.dart';
import 'package:flutter_test/flutter_test.dart';

/// NIST CAVP ECCCDH P-256 (KAS_ECC_CDH_PrimitiveTest), COUNT 0. The web client
/// derives the same Z via `crypto.subtle.deriveBits({name:"ECDH"}, …, 256)`, so
/// matching this vector is what keeps mobile and web reading the same DMs.
const _peerX = '700c48f77f56584c5cc632ca65640db91b6bacce3a4df6b42ce7cc838833d287';
const _peerY = 'db71e509e3fd9b060ddb20ba5c51dcc5948d46fbf640dfe0441782cab85fa4ac';
const _selfD = '7d7dc5f71eb29ddaf80d6214632eeae03d9058af1fb6d22ed80badb62bc1a534';
const _sharedZ = '46fc62106420ff012e54a434fbdd2d25ccc5852060561e68040dd7778997bd7b';

List<int> _hex(String value) => [
  for (var i = 0; i < value.length; i += 2)
    int.parse(value.substring(i, i + 2), radix: 16),
];

String _hexOf(List<int> bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

void main() {
  test('shared secret matches the NIST P-256 ECDH vector', () {
    final shared = P256Ecdh.sharedSecretX(
      privateD: _hex(_selfD),
      remoteX: _hex(_peerX),
      remoteY: _hex(_peerY),
    );
    expect(_hexOf(shared), _sharedZ);
  });

  test('both sides of a fresh pair agree', () {
    final a = P256Ecdh.newKeyPair();
    final b = P256Ecdh.newKeyPair();
    expect(a.d.length, 32);
    expect(a.x.length, 32);
    expect(a.y.length, 32);
    expect(
      _hexOf(P256Ecdh.sharedSecretX(privateD: a.d, remoteX: b.x, remoteY: b.y)),
      _hexOf(P256Ecdh.sharedSecretX(privateD: b.d, remoteX: a.x, remoteY: a.y)),
    );
  });

  test('coordinates with a high first byte survive the round trip', () {
    // The Android platform bridge read these as negative numbers, which is the
    // bug this class exists to avoid — assert the unsigned reading explicitly.
    final bytes = List<int>.filled(32, 0)..[0] = 0xff;
    final value = P256Ecdh.decodeCoordinate(bytes);
    expect(value.isNegative, isFalse);
    expect(_hexOf(P256Ecdh.encodeCoordinate(value)), _hexOf(bytes));
  });

  test('a point off the curve is rejected', () {
    expect(
      () => P256Ecdh.sharedSecretX(
        privateD: _hex(_selfD),
        remoteX: _hex(_peerX),
        remoteY: _hex(_peerX),
      ),
      throwsArgumentError,
    );
  });
}

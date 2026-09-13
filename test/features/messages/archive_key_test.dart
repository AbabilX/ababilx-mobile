import 'dart:convert';
import 'dart:typed_data';

import 'package:ababilx/features/messages/archive/archive_key.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';

/// A fixed scalar and salt, so the derivation is pinned rather than merely
/// self-consistent. Change the info string or the KDF and this fails — which
/// is the point: silently changing it would make every archive already written
/// unopenable, with nothing anywhere reporting why.
final _scalar = Uint8List.fromList(List<int>.generate(32, (i) => i));
final _salt = Uint8List.fromList(List<int>.generate(32, (i) => 255 - i));

void main() {
  test('derivation is pinned', () async {
    final key = await ArchiveKey.derive(_scalar, _salt);
    final bytes = await key.extractBytes();
    expect(
      base64Url.encode(bytes).replaceAll('=', ''),
      'MjdX0GdM-AqPntXg2Wm5X1Ag_DEUqMhx5kxT96e45Xs',
    );
  });

  test('a wrong-sized scalar is refused, not silently padded', () {
    expect(() => ArchiveKey.derive(Uint8List(31), _salt), throwsArgumentError);
  });

  test('round-trips a chunk', () async {
    final key = await ArchiveKey.derive(_scalar, _salt);
    final chunk = await ArchiveKey.seal(key, 7, utf8.encode('hello archive'));
    expect(utf8.decode(await ArchiveKey.open(key, 7, chunk)), 'hello archive');
  });

  test('a chunk opened at the wrong index fails the tag', () async {
    // This is what stops an archive being truncated or reordered by whoever
    // stores it: every chunk is valid only in the position it was written to.
    final key = await ArchiveKey.derive(_scalar, _salt);
    final chunk = await ArchiveKey.seal(key, 7, utf8.encode('hello archive'));
    expect(
      () => ArchiveKey.open(key, 8, chunk),
      throwsA(isA<SecretBoxAuthenticationError>()),
    );
  });

  test('the archive key is not the recovery key for the same input', () async {
    // Same 32 bytes in, different info string, so the two usages can never
    // collide. Pinned because a copy-paste of the info string would be
    // invisible in review.
    final archive = await ArchiveKey.derive(_scalar, _salt);
    final other = await Hkdf(hmac: Hmac.sha256(), outputLength: 32).deriveKey(
      secretKey: SecretKey(_scalar),
      nonce: _salt,
      info: utf8.encode('ababilx-recovery-key-v1'),
    );
    expect(await archive.extractBytes(), isNot(await other.extractBytes()));
  });
}

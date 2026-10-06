import 'dart:io';
import 'dart:typed_data';

import 'package:ababilx/features/attachments/crypto/attachment_crypto_format.dart';
import 'package:ababilx/features/attachments/crypto/attachment_file_cipher.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';

/// The `ababilx-att-v1` file format. Web and desktop must produce and read
/// these exact bytes; the fixed vector below is the contract.
void main() {
  final key = Uint8List.fromList(List<int>.generate(32, (i) => i));
  Uint8List bytes(int n) =>
      Uint8List.fromList(List<int>.generate(n, (i) => (i * 31 + 7) & 0xff));
  String hex(List<int> b) =>
      b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();

  test('format constants are pinned', () {
    expect(AttachmentCryptoFormat.algorithm, 'ababilx-att-v1');
    expect(AttachmentCryptoFormat.chunkBytes, 65536);
    expect(AttachmentCryptoFormat.tagBytes, 16);
    expect(
      hex(AttachmentCryptoFormat.chunkNonce(0)),
      '000000000000000000000000',
    );
    expect(
      hex(AttachmentCryptoFormat.chunkNonce(258)),
      '000000000000000000000102',
    );
    // "ababilx-att-v1" || u32be(index) || last
    expect(
      hex(AttachmentCryptoFormat.chunkAad(1, last: false)),
      '61626162696c782d6174742d76310000000100',
    );
    expect(
      hex(AttachmentCryptoFormat.chunkAad(258, last: true)),
      '61626162696c782d6174742d76310000010201',
    );
  });

  // Checked against an independent implementation (Node's aes-256-gcm): key
  // 00..1f, nonce twelve zero bytes, AAD "ababilx-att-v1" || 00000000 || 01,
  // plaintext 01 02 03 04 05 followed by 536 zero bytes.
  test('fixed vector: 5 bytes under key 00..1f', () async {
    final sealed = await AttachmentFileCipher.sealBytes(
      Uint8List.fromList([1, 2, 3, 4, 5]),
      key,
    );
    // 541 padded bytes in one chunk, plus its tag.
    expect(sealed.length, 557);
    expect(hex(sealed.sublist(0, 16)), '0fbeb6dab02c83bd08a8a935182c9199');
    expect(hex(sealed.sublist(541)), 'c5bee65a9bb3f66cd957bfa036c901eb');
    expect(
      hex((await Sha256().hash(sealed)).bytes),
      '2366b322bce8926371fca983182682208fcc795eab459a44d82c1fccb6eb9e01',
    );
    expect(await AttachmentFileCipher.openBytes(sealed, key, 5), [
      1,
      2,
      3,
      4,
      5,
    ]);
  });

  test('padding hides the exact size in 5% buckets', () {
    expect(AttachmentCryptoFormat.paddedSize(1), 541);
    expect(AttachmentCryptoFormat.paddedSize(541), 541);
    for (final n in [
      542,
      1000,
      65536,
      65537,
      5 * 1024 * 1024,
      350 * 1024 * 1024,
    ]) {
      final padded = AttachmentCryptoFormat.paddedSize(n);
      expect(padded, greaterThanOrEqualTo(n));
      expect(padded, lessThanOrEqualTo((n * 1.05).ceil() + 1));
      // Every size in the bucket pads to the same length.
      expect(AttachmentCryptoFormat.paddedSize(padded), padded);
    }
    expect(
      AttachmentCryptoFormat.paddedSize(1000),
      AttachmentCryptoFormat.paddedSize(1010),
    );
  });

  test('bytes round trip across chunk boundaries', () async {
    for (final n in [1, 540, 541, 65535, 65536, 65537, 200000]) {
      final plain = bytes(n);
      final sealed = await AttachmentFileCipher.sealBytes(plain, key);
      expect(sealed.length, AttachmentCryptoFormat.cipherSize(n), reason: '$n');
      final opened = await AttachmentFileCipher.openBytes(sealed, key, n);
      expect(opened, plain, reason: '$n');
    }
  });

  test('file and in-memory paths write the same object', () async {
    final dir = await Directory.systemTemp.createTemp('att-crypto');
    addTearDown(() => dir.delete(recursive: true));
    for (final n in [5, 65536, 150000]) {
      final plain = bytes(n);
      final source = File('${dir.path}/plain-$n')..writeAsBytesSync(plain);
      final cipher = File('${dir.path}/cipher-$n');
      final size = await AttachmentFileCipher.sealFile(source, cipher, key);
      expect(size, cipher.lengthSync());
      expect(
        cipher.readAsBytesSync(),
        await AttachmentFileCipher.sealBytes(plain, key),
      );
      final back = File('${dir.path}/back-$n');
      await AttachmentFileCipher.openFile(cipher, back, key, n);
      expect(back.readAsBytesSync(), plain);
    }
  });

  group('a tampered object never opens', () {
    late Uint8List sealed;
    const n = 150000; // three chunks once padded
    setUp(() async {
      sealed = await AttachmentFileCipher.sealBytes(bytes(n), key);
    });

    Future<void> refused(
      Uint8List object, {
      List<int>? withKey,
      int size = n,
    }) => expectLater(
      AttachmentFileCipher.openBytes(object, withKey ?? key, size),
      throwsA(anything),
    );

    test('wrong key', () => refused(sealed, withKey: List<int>.filled(32, 9)));

    test('one flipped byte', () {
      final bad = Uint8List.fromList(sealed)..[70000] ^= 1;
      return refused(bad);
    });

    test('cut at a chunk boundary', () {
      const chunk = 65536 + 16;
      return refused(Uint8List.sublistView(sealed, 0, chunk * 2));
    });

    test('cut mid-chunk', () {
      return refused(Uint8List.sublistView(sealed, 0, sealed.length - 40));
    });

    test('chunks swapped', () {
      const chunk = 65536 + 16;
      final bad = Uint8List.fromList(sealed);
      bad.setRange(0, chunk, sealed, chunk);
      bad.setRange(chunk, chunk * 2, sealed, 0);
      return refused(bad);
    });

    test('declared longer than it is', () => refused(sealed, size: 10 * n));

    test('a failed file open leaves no partial file', () async {
      final dir = await Directory.systemTemp.createTemp('att-crypto');
      addTearDown(() => dir.delete(recursive: true));
      final cipher = File(
        '${dir.path}/c',
      )..writeAsBytesSync(Uint8List.fromList(sealed)..[sealed.length - 1] ^= 1);
      final target = File('${dir.path}/out');
      await expectLater(
        AttachmentFileCipher.openFile(cipher, target, key, n),
        throwsA(anything),
      );
      expect(target.existsSync(), isFalse);
    });
  });
}

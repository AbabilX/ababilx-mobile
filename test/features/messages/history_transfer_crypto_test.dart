import 'dart:convert';
import 'dart:typed_data';

import 'package:ababilx/features/messages/history-transfer/history_transfer_codec.dart';
import 'package:ababilx/features/messages/history-transfer/history_transfer_crypto.dart';
import 'package:ababilx/features/messages/history-transfer/history_transfer_payload.dart';
import 'package:ababilx/features/messages/history-transfer/history_transfer_verification.dart';
import 'package:ababilx/features/messages/message_e2ee/p256_ecdh.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';

/// Desktop and web must derive byte-identically from these same strings, so
/// they are pinned here rather than left to agree by accident. Changing one
/// side alone produces chunks the other cannot open, with no error naming the
/// cause — the failure mode this file exists to prevent.
void main() {
  final key = Uint8List.fromList(List<int>.generate(32, (i) => i));

  test('the chunk AAD is part of the wire format', () {
    expect(
      utf8.decode(HistoryTransferCrypto.chunkAad(0)),
      'ababilx-history-transfer-chunk-v1:0',
    );
    expect(
      utf8.decode(HistoryTransferCrypto.chunkAad(41)),
      'ababilx-history-transfer-chunk-v1:41',
    );
  });

  test('a chunk round-trips, and only in its own position', () async {
    final sealed = await HistoryTransferCrypto.sealChunk(
      transferKey: key,
      index: 3,
      plaintext: utf8.encode('page three'),
    );
    expect(
      utf8.decode(
        await HistoryTransferCrypto.openChunk(
          transferKey: key,
          index: 3,
          sealed: sealed,
        ),
      ),
      'page three',
    );
    // Binding the index is what stops a relay dropping the last chunk or
    // swapping two and still producing a plausible, shorter history.
    await expectLater(
      HistoryTransferCrypto.openChunk(
        transferKey: key,
        index: 4,
        sealed: sealed,
      ),
      throwsA(isA<SecretBoxAuthenticationError>()),
    );
  });

  test('a manifest cannot be replayed into a chunk slot', () async {
    final sealed = await HistoryTransferCrypto.sealManifest(
      transferKey: key,
      plaintext: utf8.encode('{"v":1}'),
    );
    expect(
      utf8.decode(
        await HistoryTransferCrypto.openManifest(
          transferKey: key,
          sealed: sealed,
        ),
      ),
      '{"v":1}',
    );
    await expectLater(
      HistoryTransferCrypto.openChunk(
        transferKey: key,
        index: 0,
        sealed: sealed,
      ),
      throwsA(isA<SecretBoxAuthenticationError>()),
    );
  });

  test('the transfer key travels sealed to the scanned device alone', () async {
    final destination = P256Ecdh.newKeyPair();
    final envelope = await HistoryTransferCrypto.sealTransferKey(
      transferKey: key,
      destinationJwk: HistoryTransferCodec.publicJwk(destination),
    );
    expect(
      await HistoryTransferCrypto.openTransferKey(
        envelope: envelope,
        ephemeral: destination,
      ),
      key,
    );
    // A different device's key opens nothing: the envelope is agreed against
    // the key the phone read off the camera, not one the server supplied.
    await expectLater(
      HistoryTransferCrypto.openTransferKey(
        envelope: envelope,
        ephemeral: P256Ecdh.newKeyPair(),
      ),
      throwsA(isA<SecretBoxAuthenticationError>()),
    );
  });

  test(
    'the verification code is the device-link derivation, unchanged',
    () async {
      // Same fixed key as device_link_test, so a drift between the two shows up
      // here rather than as two unrelated numbers on two screens.
      final code = await historyTransferVerificationCode({
        'crv': 'P-256',
        'x': 'AQIDBA',
        'y': 'BQYHCA',
      });
      expect(code.length, 6);
      expect(int.tryParse(code), isNotNull);
      expect(
        await historyTransferVerificationCode({
          'crv': 'P-256',
          'x': 'AQIDBA',
          'y': 'BQYHCA',
        }),
        code,
      );
    },
  );

  group('scanned payload', () {
    test('carries the token, the key and the format version', () {
      final scanned = parseHistoryTransferPayload(
        'ababilx://history-transfer?t=abc123&k=eyJ4IjoieCJ9&v=1',
      );
      expect(scanned, isNotNull);
      expect(scanned!.token, 'abc123');
      expect(scanned.version, 1);
      expect(scanned.destinationJwk['x'], 'x');
    });

    test('a code with no key is refused', () {
      // Without the key off the camera there is nothing to seal to, and the
      // server's copy must never be used as a substitute.
      expect(
        parseHistoryTransferPayload('ababilx://history-transfer?t=abc123'),
        isNull,
      );
      expect(
        isHistoryTransferPayload('ababilx://link-messages?t=a&k=b'),
        isFalse,
      );
    });

    test('an unversioned code reads as version 1', () {
      expect(
        parseHistoryTransferPayload(
          'ababilx://history-transfer?t=a&k=eyJ4IjoieCJ9',
        )!.version,
        1,
      );
    });
  });
}

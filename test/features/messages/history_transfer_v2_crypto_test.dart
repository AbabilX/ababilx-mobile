import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:ababilx/features/messages/history-transfer/history_transfer_codec.dart';
import 'package:ababilx/features/messages/history-transfer/history_transfer_verification.dart';
import 'package:ababilx/features/messages/history-transfer/v2/v2_crypto.dart';
import 'package:ababilx/features/messages/message_e2ee/p256_ecdh.dart';
import 'package:flutter_test/flutter_test.dart';

Uint8List _hex(String value) => Uint8List.fromList([
  for (var i = 0; i < value.length; i += 2)
    int.parse(value.substring(i, i + 2), radix: 16),
]);

String _toHex(List<int> bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

/// Vectors generated with WebCrypto (the browser's own primitives) and pinned
/// in `ababilx-server/docs/fixtures/history-transfer-v2-crypto.json`. Matching
/// them here is the proof that a phone's chunks open in a browser.
void main() {
  final fixture = Map<String, dynamic>.from(
    jsonDecode(
          File(
            'test/fixtures/history_transfer/history-transfer-v2-crypto.json',
          ).readAsStringSync(),
        )
        as Map,
  );
  final transferId = fixture['transfer_id'] as String;
  final key = _hex(fixture['transfer_key_hex'] as String);
  final nonce = _hex(fixture['nonce_hex'] as String);

  test('AAD strings are the wire format', () {
    expect(
      HistoryTransferV2Crypto.chunkAad(transferId, 4, 'media', 17),
      'ababilx-history-transfer-v2|chunk|$transferId|4|media|17',
    );
    expect(
      HistoryTransferV2Crypto.pageAad(transferId, 2, 0, 3),
      'ababilx-history-transfer-v2|page|$transferId|2|0|3',
    );
  });

  for (final raw in fixture['seals'] as List) {
    final item = Map<String, dynamic>.from(raw as Map);
    test('seal ${item['purpose']}: ${item['aad']}', () async {
      final sealed = await HistoryTransferV2Crypto.seal(
        key,
        item['aad'] as String,
        utf8.encode(item['plaintext_utf8'] as String),
        nonce: nonce,
      );
      expect(HistoryTransferCodec.b64(sealed), item['sealed_b64u']);
      final opened = await HistoryTransferV2Crypto.open(
        key,
        item['aad'] as String,
        HistoryTransferCodec.bytesFromB64(item['sealed_b64u'] as String),
      );
      expect(utf8.decode(opened), item['plaintext_utf8']);
    });
  }

  test('a sealed value does not open under another position', () async {
    final sealed = await HistoryTransferV2Crypto.seal(
      key,
      HistoryTransferV2Crypto.chunkAad(transferId, 0, 'messages', 0),
      utf8.encode('x'),
    );
    expect(
      () => HistoryTransferV2Crypto.open(
        key,
        HistoryTransferV2Crypto.chunkAad(transferId, 0, 'messages', 1),
        sealed,
      ),
      throwsA(anything),
    );
  });

  test('the envelope matches WebCrypto byte for byte', () async {
    final envelope = Map<String, dynamic>.from(fixture['envelope'] as Map);
    final eph = Map<String, dynamic>.from(envelope['ephemeral_private_jwk'] as Map);
    final dest = Map<String, dynamic>.from(envelope['destination_private_jwk'] as Map);
    final pair = P256KeyPair(
      d: HistoryTransferCodec.bytesFromB64(eph['d'] as String),
      x: HistoryTransferCodec.bytesFromB64(eph['x'] as String),
      y: HistoryTransferCodec.bytesFromB64(eph['y'] as String),
    );
    final wrap = await HistoryTransferV2Crypto.wrappingKey(pair.d, dest);
    expect(_toHex(wrap), envelope['wrapping_key_hex']);
    final sealed = await HistoryTransferV2Crypto.sealEnvelope(
      transferId: transferId,
      transferKey: key,
      destinationJwk: dest,
      ephemeral: pair,
      nonce: _hex(envelope['nonce_hex'] as String),
    );
    final expected = Map<String, dynamic>.from(envelope['envelope_json'] as Map);
    expect(sealed['ciphertext'], expected['ciphertext']);
    expect(sealed['nonce'], expected['nonce']);
    final k = envelope['destination_public_param_k'] as String;
    final jwk = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(HistoryTransferCodec.bytesFromB64(k))) as Map,
    );
    expect(await historyTransferVerificationCode(jwk), envelope['verification_code']);
  });
}

import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import '../../message_e2ee/p256_ecdh.dart';
import '../history_transfer_codec.dart';

/// Protocol v2 cryptography — `ababilx-server/docs/history-transfer-v2-protocol.md`
/// section 3, pinned by `test/fixtures/history_transfer/history-transfer-v2-crypto.json`,
/// the same vectors web's tests read.
///
/// Same primitives as v1 (P-256 ECDH, SHA-256 of X, AES-256-GCM, fresh 12-byte
/// nonce, `nonce || ct || tag`); what changed is that every AAD now names the
/// transfer, the batch, the purpose and the position, so no sealed value can be
/// moved to another job, batch, index or role — and none of v1's AAD strings
/// is ever used for a v2 payload.
class HistoryTransferV2Crypto {
  HistoryTransferV2Crypto._();

  static const int version = 2;
  static const String _prefix = 'ababilx-history-transfer-v2';
  static const int nonceBytes = 12;
  static const int tagBytes = 16;
  static final _aes = AesGcm.with256bits();

  static String envelopeAad(String transferId) =>
      '$_prefix|envelope|$transferId';
  static String inventoryAad(String transferId) =>
      '$_prefix|inventory|$transferId';
  static String destInventoryAad(String transferId) =>
      '$_prefix|dest-inventory|$transferId';
  static String chunkAad(
    String transferId,
    int batch,
    String kind,
    int index,
  ) => '$_prefix|chunk|$transferId|$batch|$kind|$index';
  static String pageAad(String transferId, int batch, int index, int count) =>
      '$_prefix|page|$transferId|$batch|$index|$count';
  static String sealAad(String transferId) => '$_prefix|seal|$transferId';

  /// `nonce` is for the fixture test only; production always draws a fresh one.
  static Future<Uint8List> seal(
    List<int> key,
    String aad,
    List<int> plaintext, {
    List<int>? nonce,
  }) async {
    final iv = nonce ?? HistoryTransferCodec.randomBytes(nonceBytes);
    final box = await _aes.encrypt(
      plaintext,
      secretKey: SecretKey(key),
      nonce: iv,
      aad: utf8.encode(aad),
    );
    return Uint8List.fromList([...iv, ...box.cipherText, ...box.mac.bytes]);
  }

  static Future<Uint8List> open(
    List<int> key,
    String aad,
    List<int> sealed,
  ) async {
    if (sealed.length < nonceBytes + tagBytes) {
      throw ArgumentError('sealed payload is too short');
    }
    final bytes = Uint8List.fromList(sealed);
    final clear = await _aes.decrypt(
      SecretBox(
        bytes.sublist(nonceBytes, bytes.length - tagBytes),
        nonce: bytes.sublist(0, nonceBytes),
        mac: Mac(bytes.sublist(bytes.length - tagBytes)),
      ),
      secretKey: SecretKey(key),
      aad: utf8.encode(aad),
    );
    return Uint8List.fromList(clear);
  }

  /// JSON sealed and base64url-encoded, the form every JSON-carried value takes.
  static Future<String> sealJson(
    List<int> key,
    String aad,
    Object value,
  ) async => HistoryTransferCodec.b64(
    await seal(key, aad, utf8.encode(jsonEncode(value))),
  );

  static Future<Object?> openJson(
    List<int> key,
    String aad,
    String value,
  ) async => jsonDecode(
    utf8.decode(await open(key, aad, HistoryTransferCodec.bytesFromB64(value))),
  );

  /// Seals the transfer key to the destination's scanned ephemeral key. The
  /// wrapping key is SHA-256 of the raw ECDH X coordinate — v1's and
  /// device-link's derivation — under the v2 envelope AAD, which names the job.
  static Future<Map<String, dynamic>> sealEnvelope({
    required String transferId,
    required List<int> transferKey,
    required Map<String, dynamic> destinationJwk,
    P256KeyPair? ephemeral,
    List<int>? nonce,
  }) async {
    final pair = ephemeral ?? P256Ecdh.newKeyPair();
    final iv = nonce ?? HistoryTransferCodec.randomBytes(nonceBytes);
    final wrapping = await wrappingKey(pair.d, destinationJwk);
    final box = await _aes.encrypt(
      transferKey,
      secretKey: SecretKey(wrapping),
      nonce: iv,
      aad: utf8.encode(envelopeAad(transferId)),
    );
    return {
      'v': version,
      'ephemeral_public_key': HistoryTransferCodec.publicJwk(pair),
      'nonce': HistoryTransferCodec.b64(iv),
      'ciphertext': HistoryTransferCodec.b64([
        ...box.cipherText,
        ...box.mac.bytes,
      ]),
    };
  }

  static Future<List<int>> wrappingKey(
    List<int> privateD,
    Map<String, dynamic> remoteJwk,
  ) async {
    final shared = P256Ecdh.sharedSecretX(
      privateD: privateD,
      remoteX: HistoryTransferCodec.bytesFromB64(remoteJwk['x'] as String),
      remoteY: HistoryTransferCodec.bytesFromB64(remoteJwk['y'] as String),
    );
    return (await Sha256().hash(shared)).bytes;
  }
}

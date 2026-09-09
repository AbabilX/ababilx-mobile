import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import '../message_e2ee/p256_ecdh.dart';

/// Byte plumbing shared by the transfer's crypto, its QR payload and its
/// manifest. base64**url** without padding throughout, because these values
/// travel in a QR's query string and in JSON that a browser will read back.
class HistoryTransferCodec {
  HistoryTransferCodec._();

  static Map<String, dynamic> publicJwk(P256KeyPair key) => {
    'kty': 'EC',
    'crv': 'P-256',
    'x': b64(key.x),
    'y': b64(key.y),
    'ext': true,
    'key_ops': <String>[],
  };

  static Uint8List randomBytes(int length) {
    final random = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(length, (_) => random.nextInt(256)),
    );
  }

  static String b64(List<int> bytes) =>
      base64Url.encode(bytes).replaceAll('=', '');

  static Uint8List bytesFromB64(String value) =>
      base64Url.decode(base64Url.normalize(value));
}

import 'dart:convert';
import 'dart:typed_data';

import '../v2/v2_crypto.dart';

/// Signals of a live history link, sealed under the transfer key this phone
/// sealed to the new device's camera-read history key — protocol section 1.
/// The DTLS fingerprint rides inside the sealed SDP, so the relay cannot sit
/// in the middle of the data channel; a rewritten signal simply fails to open.
class LiveSignalSeal {
  LiveSignalSeal._();

  static String aad(String linkId, String from, String kind) =>
      'ababilx-history-live-v1|signal|$linkId|$from|$kind';

  /// `nonce` is for the fixture test only.
  static Future<Map<String, String>> seal(
    List<int> key,
    String linkId,
    String from,
    String kind,
    Map<String, dynamic> payload, {
    List<int>? nonce,
  }) async {
    final sealed = await HistoryTransferV2Crypto.seal(
      key,
      aad(linkId, from, kind),
      utf8.encode(jsonEncode(payload)),
      nonce: nonce,
    );
    const n = HistoryTransferV2Crypto.nonceBytes;
    return {
      'kind': kind,
      'nonce': _b64u(sealed.sublist(0, n)),
      'sealed': _b64u(sealed.sublist(n)),
    };
  }

  static Future<Map<String, dynamic>> open(
    List<int> key,
    String linkId,
    String from,
    Map<String, dynamic> signal,
  ) async {
    final kind = signal['kind'] as String? ?? '';
    final nonce = _fromB64u(signal['nonce'] as String? ?? '');
    final body = _fromB64u(signal['sealed'] as String? ?? '');
    final clear = await HistoryTransferV2Crypto.open(
      key,
      aad(linkId, from, kind),
      [...nonce, ...body],
    );
    return Map<String, dynamic>.from(jsonDecode(utf8.decode(clear)) as Map);
  }

  static String _b64u(List<int> bytes) =>
      base64Url.encode(bytes).replaceAll('=', '');

  static Uint8List _fromB64u(String value) =>
      base64Url.decode(value.padRight((value.length + 3) ~/ 4 * 4, '='));
}

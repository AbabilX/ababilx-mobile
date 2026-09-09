import 'dart:convert';

import 'history_transfer_codec.dart';

/// The envelope and the destination's public key travel as JSON, but the
/// server stores and compares them as opaque strings.
///
/// base64url of the compact JSON, not the JSON itself: the server's
/// `destination_public_key` check is a string equality against what the
/// destination registered, so both sides must produce the same bytes for the
/// same key. Encoding through a canonical form here is what makes that
/// comparison mean "the same key" rather than "the same whitespace".
class HistoryTransferEnvelopeCodec {
  HistoryTransferEnvelopeCodec._();

  static String encode(Map<String, dynamic> value) =>
      HistoryTransferCodec.b64(utf8.encode(jsonEncode(value)));

  static Map<String, dynamic> decode(String value) => Map<String, dynamic>.from(
    jsonDecode(utf8.decode(HistoryTransferCodec.bytesFromB64(value))) as Map,
  );
}

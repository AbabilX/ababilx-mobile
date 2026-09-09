import 'history_transfer_envelope_codec.dart';

const _scheme = 'ababilx://history-transfer';

/// A scanned history-transfer code.
///
/// `k` is the destination's ephemeral public key, read off the CAMERA. The
/// server never supplies it, and the approval echoes it back so a token that
/// arrived paired with a different key is refused rather than sealed to a
/// stranger — the same argument the device-link QR rests on.
class ScannedHistoryTransfer {
  const ScannedHistoryTransfer({
    required this.token,
    required this.publicKeyParam,
    required this.version,
  });

  final String token;
  final String publicKeyParam;

  /// The transfer format the destination says it can read. A destination
  /// asking for a version this phone does not write is refused up front, with
  /// a message naming the fix, rather than sending chunks nothing can open.
  final int version;

  Map<String, dynamic> get destinationJwk =>
      HistoryTransferEnvelopeCodec.decode(publicKeyParam);
}

bool isHistoryTransferPayload(String raw) => raw.trim().startsWith(_scheme);

ScannedHistoryTransfer? parseHistoryTransferPayload(String raw) {
  final value = raw.trim();
  if (!value.startsWith(_scheme)) return null;
  final mark = value.indexOf('?');
  if (mark < 0) return null;
  String? token;
  String? key;
  var version = 1;
  for (final part in value.substring(mark + 1).split('&')) {
    final eq = part.indexOf('=');
    if (eq <= 0) continue;
    final name = part.substring(0, eq);
    final content = part.substring(eq + 1);
    if (name == 't') token = content;
    if (name == 'k') key = content;
    if (name == 'v') version = int.tryParse(content) ?? 1;
  }
  if (token == null || key == null || token.isEmpty || key.isEmpty) return null;
  return ScannedHistoryTransfer(
    token: token,
    publicKeyParam: key,
    version: version,
  );
}

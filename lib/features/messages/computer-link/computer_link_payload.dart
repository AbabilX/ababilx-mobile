import 'dart:convert';

import 'package:cryptography/cryptography.dart';

const _scheme = 'ababilx://push-messages';
const _macPrefix = 'ababilx-message-push-v1|';

/// One "send messages to my phone" code, read off a computer's screen
/// (server 0182). The computer holds the message identity; this phone has
/// none and receives it.
///
/// `secret` never reaches the server: it MACs the phone's ephemeral key, so a
/// key swapped on the way to the computer is refused there and nothing is
/// sealed to it. Pinned with desktop's `push-link.ts` by
/// `computer_link_payload_test.dart` — change one side alone and every
/// transfer is refused.
class ComputerLinkCode {
  const ComputerLinkCode({required this.token, required this.secret});
  final String token;
  final List<int> secret;
}

bool isComputerLinkPayload(String raw) => raw.trim().startsWith('$_scheme?');

ComputerLinkCode? parseComputerLinkPayload(String raw) {
  final value = raw.trim();
  if (!isComputerLinkPayload(value)) return null;
  String? token;
  String? secret;
  for (final part in value.substring(value.indexOf('?') + 1).split('&')) {
    final eq = part.indexOf('=');
    if (eq <= 0) continue;
    final name = part.substring(0, eq);
    final content = part.substring(eq + 1);
    if (name == 't') token = content;
    if (name == 's') secret = content;
  }
  if (token == null || !RegExp(r'^[0-9a-f]{64}$').hasMatch(token)) return null;
  if (secret == null) return null;
  final bytes = _fromB64Url(secret);
  if (bytes == null || bytes.length != 32) return null;
  return ComputerLinkCode(token: token, secret: bytes);
}

/// HMAC-SHA256(secret, "ababilx-message-push-v1|crv.x.y"), base64url.
Future<String> computerLinkKeyMac(
  List<int> secret,
  Map<String, dynamic> publicJwk,
) async {
  final mac = await Hmac.sha256().calculateMac(
    utf8.encode('$_macPrefix${publicJwk['crv']}.${publicJwk['x']}.${publicJwk['y']}'),
    secretKey: SecretKey(secret),
  );
  return base64Url.encode(mac.bytes).replaceAll('=', '');
}

List<int>? _fromB64Url(String value) {
  try {
    return base64Url.decode(base64Url.normalize(value));
  } on FormatException {
    return null;
  }
}

import 'dart:convert';
import 'dart:math';

const transferChatsScheme = 'ababilx://transfer-chats';
const transferChatsVersion = 1;
const transferSecretBytes = 32;

/// What the NEW device draws and the old one reads with its camera
/// (TRANSFER_CHATS_PROTOCOL.md at the monorepo root).
///
/// The camera is the only channel the secret and the link key travel on:
/// nothing here is ever sent to the server, so whoever can read the transfer
/// had to see this screen.
class TransferChatsCode {
  const TransferChatsCode({
    required this.addresses,
    required this.secret,
    required this.linkKey,
    required this.userId,
    required this.sessionId,
    this.pull = false,
  });

  /// `ip:port` of the new device on the local network, best first.
  final List<String> addresses;

  /// 32 random bytes: seals the stream and derives the request token.
  final List<int> secret;

  /// The new device's ephemeral P-256 public key, as the device link encodes
  /// it (`MessageVault.encodeLinkPublicKey`). The message key is sealed to it.
  final String linkKey;

  /// The account the new device is signed in to.
  final String userId;

  /// The new device's sign-in. The old device finds it in its own account's
  /// session list before it sends anything.
  final String sessionId;

  /// `r=pull`: a computer drew this code (it has no camera) and SENDS. The
  /// phone that scans it is the new device: it gives its own link key in
  /// `hello` and takes the stream. No `k` in the code then.
  final bool pull;
}

List<int> newTransferSecret() {
  final random = Random.secure();
  return List<int>.generate(transferSecretBytes, (_) => random.nextInt(256));
}

String buildTransferChatsPayload(TransferChatsCode code) {
  final params = {
    'v': '$transferChatsVersion',
    if (code.pull) 'r': 'pull',
    'a': code.addresses.join(','),
    's': base64Url.encode(code.secret).replaceAll('=', ''),
    if (!code.pull) 'k': code.linkKey,
    'u': code.userId,
    'sid': code.sessionId,
  };
  final query = params.entries
      .map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}')
      .join('&');
  return '$transferChatsScheme?$query';
}

bool isTransferChatsPayload(String raw) =>
    raw.trim().startsWith('$transferChatsScheme?');

/// Null for anything that is not a complete version-1 code.
TransferChatsCode? parseTransferChatsPayload(String raw) {
  final value = raw.trim();
  if (!isTransferChatsPayload(value)) return null;
  final Map<String, String> q;
  try {
    q = Uri.splitQueryString(value.substring(value.indexOf('?') + 1));
  } catch (_) {
    return null;
  }
  if (q['v'] != '$transferChatsVersion') return null;
  final addresses = (q['a'] ?? '').split(',').where(isTransferAddress).toList();
  final secret = _bytes(q['s'] ?? '');
  final linkKey = q['k'] ?? '';
  final userId = q['u'] ?? '';
  final sessionId = q['sid'] ?? '';
  final pull = q['r'] == 'pull';
  if (addresses.isEmpty ||
      secret == null ||
      secret.length != transferSecretBytes ||
      (linkKey.isEmpty && !pull) ||
      userId.isEmpty ||
      sessionId.isEmpty) {
    return null;
  }
  return TransferChatsCode(
    addresses: addresses,
    secret: secret,
    linkKey: linkKey,
    userId: userId,
    sessionId: sessionId,
    pull: pull,
  );
}

final _address = RegExp(
  r'^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3}):(\d{1,5})$',
);

/// `a.b.c.d:port` with every number in range. A name is refused: the old
/// device must not be pointed at a host the code's author picked.
bool isTransferAddress(String value) {
  final m = _address.firstMatch(value);
  if (m == null) return false;
  for (var i = 1; i <= 4; i++) {
    if (int.parse(m.group(i)!) > 255) return false;
  }
  final port = int.parse(m.group(5)!);
  return port > 0 && port <= 65535;
}

List<int>? _bytes(String value) {
  try {
    return base64Url.decode(base64Url.normalize(value));
  } catch (_) {
    return null;
  }
}

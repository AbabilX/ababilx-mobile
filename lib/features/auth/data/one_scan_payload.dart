/// The extra keys a one-scan sign-in QR carries (2026-10-02).
///
/// `ababilx://desktop-login?t=<token>&k=<link key>&h=<history key>&hv=2`
///
/// `k` is the new device's ephemeral device-link key and `h` its history
/// transfer key — the same two keys the separate link and history codes used
/// to carry. Both come off the CAMERA, never from the server, which is what
/// keeps the server relaying ciphertext for keys it never supplied. A code
/// from an older web or desktop build has neither, and the flow is a plain
/// sign-in, exactly as before.
class OneScanKeys {
  const OneScanKeys({
    this.linkKeyParam,
    this.historyKeyParam,
    this.historyVersion = 2,
  });

  final String? linkKeyParam;
  final String? historyKeyParam;
  final int historyVersion;

  bool get hasLinkKey => linkKeyParam != null;
  bool get hasHistoryKey => historyKeyParam != null;
}

OneScanKeys parseOneScanKeys(String raw) {
  final value = raw.trim();
  final mark = value.indexOf('?');
  if (mark < 0) return const OneScanKeys();
  String? link;
  String? history;
  var version = 2;
  for (final part in value.substring(mark + 1).split('&')) {
    final eq = part.indexOf('=');
    if (eq <= 0) continue;
    final name = part.substring(0, eq);
    final content = part.substring(eq + 1);
    if (content.isEmpty) continue;
    if (name == 'k') link = content;
    if (name == 'h') history = content;
    if (name == 'hv') version = int.tryParse(content) ?? 2;
  }
  return OneScanKeys(
    linkKeyParam: link,
    historyKeyParam: history,
    historyVersion: version,
  );
}

/// The bare sign-in token, which is what the history endpoints match on.
String signInTokenOf(String raw) {
  final value = raw.trim();
  final at = value.indexOf('t=');
  if (at < 0 || !value.startsWith('ababilx://')) return value;
  final rest = value.substring(at + 2);
  final end = rest.indexOf('&');
  return end < 0 ? rest : rest.substring(0, end);
}

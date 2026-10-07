/// A markdown link shows one text and opens another address, and every chat
/// bubble is markdown: `[bank.com](https://evil.example)` reads as the bank.
///
/// Answers the host [url] really opens when [label] itself reads as an
/// address on a different site, else null. A label of ordinary words
/// ("the report") is not a claim about where the link goes and is left alone.
String? disguisedLinkHost(String label, String url) {
  final shown = label.trim();
  if (!_looksLikeAddress.hasMatch(shown)) return null;
  final claimed = _host(shown);
  final real = _host(url.trim());
  if (claimed == null || real == null || _sameSite(claimed, real)) return null;
  return real;
}

/// `bank.com`, `www.bank.com/login`, `https://bank.com` — one run, no spaces,
/// with a dot and a letters-only ending.
final _looksLikeAddress = RegExp(
  r'^(https?://)?[^\s/@?#]+\.[a-z]{2,}([/?#]\S*)?$',
  caseSensitive: false,
);

String? _host(String address) {
  var uri = Uri.tryParse(address);
  if (uri == null) return null;
  // No scheme is how a bare `bank.com/pay` is written; anything that names a
  // scheme other than the web's (mailto, tel) is not a page with a host.
  if (!uri.hasScheme) uri = Uri.tryParse('https://$address');
  final scheme = uri?.scheme.toLowerCase();
  if (uri == null || (scheme != 'http' && scheme != 'https')) return null;
  final host = uri.host.toLowerCase();
  if (host.isEmpty) return null;
  return host.startsWith('www.') ? host.substring(4) : host;
}

/// The same host, or one a subdomain of the other: `docs.bank.com` under a
/// label of `bank.com` is the bank's own.
bool _sameSite(String a, String b) =>
    a == b || a.endsWith('.$b') || b.endsWith('.$a');

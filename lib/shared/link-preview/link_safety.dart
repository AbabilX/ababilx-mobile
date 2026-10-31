/// The reference Android app's `util/LinkUtil.kt`, ported. A link is only
/// fetched — and only drawn — if it survives every one of these.
///
/// The point of the mixed-script rule is the one worth remembering: `аpple.com`
/// with a Cyrillic а would otherwise unfurl into a card carrying Apple's real
/// title and logo, which is a far better lure than the bare link ever was.
library;

import 'dart:io';

/// Domains that exist to be examples, and the two darknet TLDs a phone cannot
/// reach anyway.
const _invalidDomains = [
  'example',
  r'example\.com',
  r'example\.net',
  r'example\.org',
  'i2p',
  'invalid',
  'localhost',
  'onion',
  'test',
];

final _invalidDomainsRegex = RegExp(
  '^(.+\\.)?(${_invalidDomains.join('|')})\\.?\$',
  caseSensitive: false,
);

/// Bidi overrides and the box-drawing block — the characters used to paint a
/// convincing fake URL inside a real one.
final _illegalCharacters = RegExp('[\u202C\u202D\u202E\u2500-\u25FF]');

/// `..` or an ellipsis inside the host.
final _illegalPeriods = RegExp(r'(\.{2,}|\u2026)');

final _domainPattern = RegExp(r'^(https?://)?([^/]+).*$');
final _allAscii = RegExp(r'^[\x00-\x7F]*$');
final _allNonAscii = RegExp(r'^[^\x00-\x7F]*$');

/// Whether [url] may be unfurled. Mirrors `LinkUtil.isValidPreviewUrl`.
bool isValidPreviewUrl(String? url) {
  if (url == null || url.isEmpty) return false;

  final domain = _legalDomain(url);
  if (domain == null) return false;
  if (_invalidDomainsRegex.hasMatch(domain)) return false;

  final uri = Uri.tryParse(url);
  if (uri == null || !uri.hasScheme) return false;

  // https only. Not a style choice: a preview fetched over http is a request
  // anyone on the path can read and rewrite, for a URL somebody else chose.
  if (uri.scheme != 'https') return false;

  final host = uri.host;
  if (host.isEmpty) return false;
  if (_invalidDomainsRegex.hasMatch(host)) return false;
  if (isPrivateOrLocalHost(host)) return false;

  return true;
}

/// The host as WRITTEN, when the URL uses legal characters throughout; null
/// otherwise. Read out of the raw string on purpose — `Uri.host` has already
/// punycoded an international domain, which is exactly the difference the
/// mixed-script test below is looking for.
String? _legalDomain(String url) {
  if (_illegalCharacters.hasMatch(url)) return null;

  final match = _domainPattern.firstMatch(url);
  final domain = match?.group(2);
  if (domain == null || domain.isEmpty) return null;
  if (_illegalPeriods.hasMatch(domain)) return null;

  final cleaned = domain.replaceAll('.', '');
  final legal = _allAscii.hasMatch(cleaned) || _allNonAscii.hasMatch(cleaned);
  return legal ? domain : null;
}

/// True when the host is an IP literal pointing back inside the network the
/// phone is on. A NAME resolving to a private address is deliberately NOT
/// caught here — that is the reference app's own boundary, and closing it needs
/// the resolved address at dial time, which Dart's HTTP client does not expose.
bool isPrivateOrLocalHost(String host) {
  final literal = host.startsWith('[') && host.endsWith(']')
      ? host.substring(1, host.length - 1)
      : host;
  final address = InternetAddress.tryParse(literal);
  if (address == null) return false;
  if (address.isLoopback || address.isLinkLocal || address.isMulticast) {
    return true;
  }

  final bytes = address.rawAddress;
  if (bytes.length == 4) {
    if (bytes[0] == 0) return true; // 0.0.0.0/8, "this network".
    if (bytes[0] == 10) return true;
    if (bytes[0] == 172 && bytes[1] >= 16 && bytes[1] <= 31) return true;
    if (bytes[0] == 192 && bytes[1] == 168) return true;
    // Carrier-grade NAT: a phone on mobile data sits inside 100.64/10, so its
    // carrier's own boxes are reachable from here and nowhere else.
    if (bytes[0] == 100 && bytes[1] >= 64 && bytes[1] <= 127) return true;
    return false;
  }
  if (bytes.length == 16) {
    if (bytes.every((b) => b == 0)) return true; // ::
    return (bytes[0] & 0xfe) == 0xfc; // fc00::/7, unique local.
  }
  return false;
}

/// The domain shown on the card. The reference app draws `topPrivateDomain()`;
/// without a public-suffix list the closest honest thing is the host minus a
/// leading `www.`, which is what every card in practice ends up showing anyway.
String previewDomain(String url) {
  final host = Uri.tryParse(url)?.host ?? '';
  if (host.isEmpty) return url;
  return host.startsWith('www.') ? host.substring(4) : host;
}

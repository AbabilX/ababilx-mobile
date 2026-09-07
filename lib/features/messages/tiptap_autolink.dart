/// Detects tappable URLs, emails and phone numbers in a message body.
///
/// Web TipTap only autolinks `http(s):` while typing. Mobile compose never
/// writes a `link` mark, so render-time detection is what makes a pasted
/// number or address open the dialer / mailer. Overlaps resolve left-to-right,
/// longer match first: a URL wins over a phone that happens to sit in its path.
library;

enum AutolinkKind { url, email, phone }

class AutolinkHit {
  const AutolinkHit({
    required this.kind,
    required this.start,
    required this.end,
    required this.text,
    required this.href,
  });

  final AutolinkKind kind;
  final int start;
  final int end;
  final String text;
  final String href;
}

final _urlRe = RegExp(
  r'(?:https?:\/\/|www\.)[^\s<>\[\]()"]+',
  caseSensitive: false,
);
final _emailRe = RegExp(
  r'[A-Z0-9._%+\-]+@[A-Z0-9.\-]+\.[A-Z]{2,}',
  caseSensitive: false,
);
final _urlTrailRe = RegExp(r'[.,;:!?)]+$');
final _softTrailRe = RegExp(r'[.,;:!?]+$');

/// Phone-shaped run: optional + / 00, then digits with common separators.
/// Validated after the match so invoice IDs and years do not light up.
final _phoneRe = RegExp(
  r'(?<![\w])(?:\+|00)?\(?\d[\d\s().\-]{6,20}\d(?![\w])',
);

List<AutolinkHit> detectAutolinks(String text) {
  if (text.isEmpty) return const [];
  final candidates = <AutolinkHit>[
    ..._scanUrls(text),
    ..._scanEmails(text),
    ..._scanPhones(text),
  ]..sort((a, b) {
    final byStart = a.start.compareTo(b.start);
    if (byStart != 0) return byStart;
    return b.end.compareTo(a.end);
  });

  final hits = <AutolinkHit>[];
  var cursor = 0;
  for (final hit in candidates) {
    if (hit.start < cursor) continue;
    hits.add(hit);
    cursor = hit.end;
  }
  return hits;
}

List<AutolinkHit> _scanUrls(String text) {
  final hits = <AutolinkHit>[];
  for (final match in _urlRe.allMatches(text)) {
    var raw = match.group(0)!;
    var end = match.end;
    final trailing = _urlTrailRe.firstMatch(raw)?.group(0) ?? '';
    if (trailing.isNotEmpty) {
      raw = raw.substring(0, raw.length - trailing.length);
      end -= trailing.length;
    }
    if (raw.isEmpty) continue;
    final href = raw.toLowerCase().startsWith('www.') ? 'https://$raw' : raw;
    hits.add(
      AutolinkHit(
        kind: AutolinkKind.url,
        start: match.start,
        end: end,
        text: raw,
        href: href,
      ),
    );
  }
  return hits;
}

List<AutolinkHit> _scanEmails(String text) {
  final hits = <AutolinkHit>[];
  for (final match in _emailRe.allMatches(text)) {
    var raw = match.group(0)!;
    var end = match.end;
    final trailing = _softTrailRe.firstMatch(raw)?.group(0) ?? '';
    if (trailing.isNotEmpty) {
      raw = raw.substring(0, raw.length - trailing.length);
      end -= trailing.length;
    }
    hits.add(
      AutolinkHit(
        kind: AutolinkKind.email,
        start: match.start,
        end: end,
        text: raw,
        href: 'mailto:$raw',
      ),
    );
  }
  return hits;
}

List<AutolinkHit> _scanPhones(String text) {
  final hits = <AutolinkHit>[];
  for (final match in _phoneRe.allMatches(text)) {
    final raw = match.group(0)!;
    if (!_isPhone(raw)) continue;
    hits.add(
      AutolinkHit(
        kind: AutolinkKind.phone,
        start: match.start,
        end: match.end,
        text: raw,
        href: phoneHref(raw),
      ),
    );
  }
  return hits;
}

bool _isPhone(String raw) {
  final digits = raw.replaceAll(RegExp(r'\D'), '');
  if (digits.length < 8 || digits.length > 15) return false;

  final compact = raw.replaceAll(RegExp(r'[\s().\-]'), '');
  if (compact.startsWith('+') || compact.startsWith('00')) {
    return digits.length >= 8;
  }
  // Local BD mobile: 01[3-9]XXXXXXXX
  if (RegExp(r'^01[3-9]\d{8}$').hasMatch(digits)) return true;
  // Separators make a 10+ digit run look like a number people typed to dial.
  final separated = RegExp(r'[\s().\-]').hasMatch(raw);
  return separated && digits.length >= 10;
}

String phoneHref(String raw) {
  final digits = raw.replaceAll(RegExp(r'\D'), '');
  final compact = raw.replaceAll(RegExp(r'[\s().\-]'), '');
  if (compact.startsWith('+')) return 'tel:+$digits';
  if (compact.startsWith('00') && digits.length > 2) {
    return 'tel:+${digits.substring(2)}';
  }
  return 'tel:$digits';
}

/// The reference Android app's `LinkPreviewUtil.parseOpenGraphFields`, with one
/// shape change: the reference app writes a separate pattern per property
/// family and only ever matches double-quoted attributes. This reads a `<meta>`
/// tag's attributes once and takes whichever key it finds, so `og:`, `article:`
/// and single-quoted markup all land in the same map.
///
/// Deliberately regex over a DOM: the page is untrusted, arrives half-read at
/// the byte cap, and only six fields are wanted. It is the same trade the
/// desktop's Rust scanner makes.
library;

import 'link_preview_data.dart';

final _metaTag = RegExp(r'<\s*meta\b[^>]*>', caseSensitive: false);
final _linkTag = RegExp(r'<\s*link\b[^>]*>', caseSensitive: false);
final _titleTag = RegExp(
  r'<\s*title[^>]*>([\s\S]*?)<\s*/\s*title\s*>',
  caseSensitive: false,
);
final _attribute = RegExp(
  '''([A-Za-z_:][-A-Za-z0-9_:.]*)\\s*=\\s*("[^"]*"|'[^']*'|[^\\s"'>]+)''',
);

/// A description longer than this is a page dumping its article into a tag.
const _maxDescription = 600;

/// Parses [html] fetched from [url]. Relative image URLs are resolved against
/// it — the reference app leaves a relative favicon href as it found it, which
/// simply fails to load later.
LinkPreviewData parseLinkPreview(String url, String html) {
  final tags = <String, String>{};

  for (final match in _metaTag.allMatches(html)) {
    final attributes = _attributes(match.group(0)!);
    final key = attributes['property'] ?? attributes['name'];
    final content = attributes['content'];
    if (key == null || content == null || content.isEmpty) continue;
    // First tag wins: a page that repeats og:title means the first one.
    tags.putIfAbsent(key.toLowerCase(), () => content);
  }

  String? icon;
  for (final match in _linkTag.allMatches(html)) {
    final attributes = _attributes(match.group(0)!);
    final rel = attributes['rel']?.toLowerCase();
    final href = attributes['href'];
    if (rel == null || href == null || href.isEmpty) continue;
    if (!rel.contains('icon')) continue;
    icon = href;
    break;
  }

  final htmlTitle = _titleTag.firstMatch(html)?.group(1);

  return LinkPreviewData(
    url: url,
    title: _tidy(tags['og:title'] ?? tags['twitter:title'] ?? htmlTitle),
    description: _tidy(
      tags['og:description'] ??
          tags['twitter:description'] ??
          tags['description'],
      limit: _maxDescription,
    ),
    // The reference app falls back to the favicon when there is no og:image,
    // and so do we: a small square is exactly what the 72dp thumbnail slot
    // wants.
    imageUrl: _absolute(url, tags['og:image'] ?? tags['twitter:image'] ?? icon),
    siteName: _tidy(tags['og:site_name']),
  );
}

Map<String, String> _attributes(String tag) {
  final out = <String, String>{};
  for (final match in _attribute.allMatches(tag)) {
    var value = match.group(2)!;
    if (value.length >= 2 &&
        (value.startsWith('"') || value.startsWith("'")) &&
        value[0] == value[value.length - 1]) {
      value = value.substring(1, value.length - 1);
    }
    out.putIfAbsent(match.group(1)!.toLowerCase(), () => decodeEntities(value));
  }
  return out;
}

String? _tidy(String? value, {int limit = 200}) {
  if (value == null) return null;
  // The reference app decodes twice: plenty of pages emit `&amp;quot;` in a
  // meta tag.
  final text = decodeEntities(
    decodeEntities(value),
  ).replaceAll(RegExp(r'\s+'), ' ').trim();
  if (text.isEmpty) return null;
  return text.length <= limit ? text : '${text.substring(0, limit)}…';
}

String? _absolute(String base, String? value) {
  if (value == null || value.isEmpty) return null;
  final resolved = Uri.tryParse(base)?.resolve(value);
  if (resolved == null) return null;
  // A `javascript:` or `data:` image is not one, and neither is anything we
  // would refuse to fetch.
  if (resolved.scheme != 'http' && resolved.scheme != 'https') return null;
  return resolved.toString();
}

const _namedEntities = {
  'amp': '&',
  'lt': '<',
  'gt': '>',
  'quot': '"',
  'apos': "'",
  'nbsp': ' ',
};

final _entity = RegExp(
  r'&(#[0-9]+|#[xX][0-9a-fA-F]+|[A-Za-z][A-Za-z0-9]{1,30});',
);

/// Named and numeric HTML entities. Anything unrecognised is left as written —
/// a literal `&foo;` in a title is better than losing the rest of the string.
String decodeEntities(String value) {
  if (!value.contains('&')) return value;
  return value.replaceAllMapped(_entity, (match) {
    final body = match.group(1)!;
    if (body.startsWith('#')) {
      final isHex = body.length > 1 && (body[1] == 'x' || body[1] == 'X');
      final digits = isHex ? body.substring(2) : body.substring(1);
      final code = int.tryParse(digits, radix: isHex ? 16 : 10);
      if (code == null || code <= 0 || code > 0x10ffff) return match.group(0)!;
      return String.fromCharCode(code);
    }
    return _namedEntities[body.toLowerCase()] ?? match.group(0)!;
  });
}

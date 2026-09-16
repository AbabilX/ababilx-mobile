import 'dart:convert';

/// A JPack as it travels: inside the message body, not beside it.
///
/// A JPack is a greeting card — a cover and a message — and carries no money.
///
/// The send API carries `body` and nothing else a client chooses — no
/// `message_type`, no `meta` — and in a DM only `body` is sealed. So the card
/// rides as a TipTap doc whose `attrs.jpack` holds the data, and whose one
/// paragraph is a readable line. Everything that reads a body as text
/// (`tiptapToPlainText`: chat-list previews, notifications, search, web,
/// desktop, older builds of this app) ignores `attrs` and shows that line;
/// this build finds `attrs.jpack` and draws the card.
class JPackPayload {
  const JPackPayload({
    required this.id,
    required this.coverId,
    required this.message,
    this.lang = 'bn',
  });

  /// 2 dropped the amount. A v1 body still parses; its amount is ignored.
  static const version = 2;

  /// Stable across devices; "opened" is remembered by it.
  final String id;
  final String coverId;
  final String message;
  final String lang;

  Map<String, dynamic> toJson() => {
    'v': version,
    'id': id,
    'cover': coverId,
    'message': message,
    'lang': lang,
  };

  /// The line every client that does not know JPack shows instead.
  String get fallbackText {
    final text = message.trim();
    return text.isEmpty ? '💌 JPack' : '💌 JPack · $text';
  }

  static final _cache = <String, JPackPayload?>{};

  /// The JPack in [body], or null for every other message. Memoised on the
  /// body string: bubbles call this on every rebuild while scrolling.
  static JPackPayload? tryParse(String? body) {
    final trimmed = body?.trim() ?? '';
    // Cheap reject first — almost every body is not a JPack.
    if (trimmed.isEmpty || !trimmed.contains('"jpack"')) return null;
    if (_cache.containsKey(trimmed)) return _cache[trimmed];
    final parsed = _parse(trimmed);
    if (_cache.length > 256) _cache.clear();
    _cache[trimmed] = parsed;
    return parsed;
  }

  static JPackPayload? _parse(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map || decoded['type'] != 'doc') return null;
      final attrs = decoded['attrs'];
      if (attrs is! Map) return null;
      final j = attrs['jpack'];
      if (j is! Map) return null;
      final id = j['id'];
      if (id is! String || id.isEmpty) return null;
      return JPackPayload(
        id: id,
        coverId: j['cover'] is String ? j['cover'] as String : 'classic',
        message: j['message'] is String ? j['message'] as String : '',
        lang: j['lang'] is String ? j['lang'] as String : 'bn',
      );
    } catch (_) {
      return null;
    }
  }
}

/// The message body for [payload]. See [JPackPayload] for why it is a doc.
String encodeJPackBody(JPackPayload payload) => jsonEncode({
  'type': 'doc',
  'attrs': {'jpack': payload.toJson()},
  'content': [
    {
      'type': 'paragraph',
      'content': [
        {'type': 'text', 'text': payload.fallbackText},
      ],
    },
  ],
});

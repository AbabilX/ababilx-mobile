import 'dart:convert';

/// The key under `attrs` in the body. Still `jpack` — the feature's first
/// name — because every card already sent carries it.
const khaamWireKey = 'jpack';

/// What a Khaam reads as anywhere the card is not drawn.
String khaamLabel(String lang) => lang == 'bn' ? '💌 খাম' : '💌 Khaam';

/// Longest caption a Khaam takes. It is written on the envelope's flap, two
/// short lines at most; every ready-made message fits (the longest is 34).
const khaamCaptionMaxChars = 36;

/// A Khaam's photo rides as the message's own attachment under this name, so
/// the card can find it and every list of a chat's media can leave it out.
String khaamPhotoFileName(String id) => 'khaam-$id.jpg';

bool isKhaamPhotoFile(String fileName) => fileName.startsWith('khaam-');

/// A Khaam as it travels: inside the message body, not beside it.
///
/// A Khaam is a greeting card — a cover and a message — and carries no money.
///
/// The send API carries `body` and nothing else a client chooses — no
/// `message_type`, no `meta` — and in a DM only `body` is sealed. So the card
/// rides as a TipTap doc whose `attrs.jpack` holds the data, and whose one
/// paragraph is a readable line. Everything that reads a body as text
/// (chat-list previews, notifications, search, web, desktop, older builds of
/// this app) ignores `attrs` and shows that line; this build finds
/// `attrs.jpack` and draws the card.
///
/// The line is the label alone, never the message: the message is a
/// surprise until the receiver scratches the card open, so a notification or
/// a preview must not give it away.
class KhaamPayload {
  const KhaamPayload({
    required this.id,
    required this.coverId,
    required this.message,
    this.lang = 'bn',
    this.photo,
  });

  /// 2 dropped the amount. A v1 body still parses; its amount is ignored.
  static const version = 2;

  /// Stable across devices; "opened" is remembered by it.
  final String id;
  final String coverId;
  final String message;
  final String lang;

  /// File name of the attached memory photo, or null for a card without one.
  final String? photo;

  Map<String, dynamic> toJson() => {
    'v': version,
    'id': id,
    'cover': coverId,
    'message': message,
    'lang': lang,
    'photo': ?photo,
  };

  /// The line every client that does not know Khaam shows instead.
  String get fallbackText => khaamLabel(lang);

  static final _cache = <String, KhaamPayload?>{};

  /// The Khaam in [body], or null for every other message. Memoised on the
  /// body string: bubbles call this on every rebuild while scrolling.
  static KhaamPayload? tryParse(String? body) {
    final trimmed = body?.trim() ?? '';
    // Cheap reject first — almost every body is not a Khaam.
    if (trimmed.isEmpty || !trimmed.contains('"jpack"')) return null;
    if (_cache.containsKey(trimmed)) return _cache[trimmed];
    final parsed = _parse(trimmed);
    if (_cache.length > 256) _cache.clear();
    _cache[trimmed] = parsed;
    return parsed;
  }

  static KhaamPayload? _parse(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map || decoded['type'] != 'doc') return null;
      final attrs = decoded['attrs'];
      if (attrs is! Map) return null;
      final j = attrs[khaamWireKey];
      if (j is! Map) return null;
      final id = j['id'];
      if (id is! String || id.isEmpty) return null;
      return KhaamPayload(
        id: id,
        coverId: j['cover'] is String ? j['cover'] as String : 'classic',
        message: j['message'] is String ? j['message'] as String : '',
        lang: j['lang'] is String ? j['lang'] as String : 'bn',
        photo: j['photo'] is String ? j['photo'] as String : null,
      );
    } catch (_) {
      return null;
    }
  }
}

/// The message body for [payload]. See [KhaamPayload] for why it is a doc.
String encodeKhaamBody(KhaamPayload payload) => jsonEncode({
  'type': 'doc',
  'attrs': {khaamWireKey: payload.toJson()},
  'content': [
    {
      'type': 'paragraph',
      'content': [
        {'type': 'text', 'text': payload.fallbackText},
      ],
    },
  ],
});

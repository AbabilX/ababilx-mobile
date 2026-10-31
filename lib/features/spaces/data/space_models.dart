/// Wire and cache shapes for Spaces (SPACES.md). Parsing is tolerant: a
/// malformed row is skipped, an unknown value falls back, nothing throws —
/// a newer server or a corrupt cache must never blank the screen.
library;

import 'package:flutter/widgets.dart' show StringCharacters;

enum SpaceChannelKind { text, announcement }

SpaceChannelKind _kind(Object? v) =>
    v == 'announcement' ? SpaceChannelKind.announcement : SpaceChannelKind.text;

String _str(Object? v) => v is String ? v : '';
int _int(Object? v) => v is num && v > 0 ? v.toInt() : 0;
Map<String, dynamic>? _map(Object? v) =>
    v is Map ? Map<String, dynamic>.from(v) : null;
List<Map<String, dynamic>> _maps(Object? v) => [
  if (v is List)
    for (final e in v) ?_map(e),
];

/// One Space in the rail.
class SpaceSummary {
  const SpaceSummary({
    required this.id,
    required this.name,
    this.iconUrl = '',
    this.unread = false,
    this.mentions = 0,
  });

  final String id;
  final String name;
  final String iconUrl;
  final bool unread;
  final int mentions;

  static SpaceSummary? fromJson(Map<String, dynamic> j) {
    final id = _str(j['id']);
    if (id.isEmpty) return null;
    return SpaceSummary(
      id: id,
      name: _str(j['name']),
      iconUrl: _str(j['icon_url']),
      unread: j['unread'] == true,
      mentions: _int(j['mentions']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'icon_url': iconUrl,
    'unread': unread,
    'mentions': mentions,
  };

  /// `{spaces: [...]}`, the body of GET /v1/spaces.
  static List<SpaceSummary> listFromJson(Object? body) => [
    for (final m in _maps(_map(body)?['spaces'])) ?fromJson(m),
  ];

  static Map<String, dynamic> listToJson(List<SpaceSummary> list) => {
    'spaces': [for (final s in list) s.toJson()],
  };
}

class SpaceChannel {
  const SpaceChannel({
    required this.id,
    required this.name,
    this.kind = SpaceChannelKind.text,
    this.isPrivate = false,
    this.unread = false,
    this.mentions = 0,
  });

  final String id;
  final String name;
  final SpaceChannelKind kind;
  final bool isPrivate;
  final bool unread;
  final int mentions;

  static SpaceChannel? fromJson(Map<String, dynamic> j) {
    final id = _str(j['id']);
    if (id.isEmpty) return null;
    return SpaceChannel(
      id: id,
      name: _str(j['name']),
      kind: _kind(j['kind']),
      isPrivate: j['private'] == true,
      unread: j['unread'] == true,
      mentions: _int(j['mentions']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'kind': kind.name,
    'private': isPrivate,
    'unread': unread,
    'mentions': mentions,
  };

  static List<SpaceChannel> listFromJson(Object? v) => [
    for (final m in _maps(v)) ?fromJson(m),
  ];
}

class SpaceCategory {
  const SpaceCategory({
    required this.id,
    required this.name,
    this.isPrivate = false,
    this.channels = const [],
  });

  final String id;
  final String name;
  final bool isPrivate;
  final List<SpaceChannel> channels;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'private': isPrivate,
    'channels': [for (final c in channels) c.toJson()],
  };
}

/// One Space's sidebar: channels outside any category first, then categories.
class SpaceTree {
  const SpaceTree({
    required this.spaceId,
    required this.name,
    this.channels = const [],
    this.categories = const [],
  });

  final String spaceId;
  final String name;
  final List<SpaceChannel> channels;
  final List<SpaceCategory> categories;

  /// Body of GET /v1/spaces/:id/channels (also the cache format).
  static SpaceTree fromJson(String spaceId, Object? body) {
    final j = _map(body) ?? const {};
    return SpaceTree(
      spaceId: spaceId,
      name: _str(_map(j['space'])?['name']),
      channels: SpaceChannel.listFromJson(j['channels']),
      categories: [
        for (final c in _maps(j['categories']))
          if (_str(c['id']).isNotEmpty)
            SpaceCategory(
              id: _str(c['id']),
              name: _str(c['name']),
              isPrivate: c['private'] == true,
              channels: SpaceChannel.listFromJson(c['channels']),
            ),
      ],
    );
  }

  Map<String, dynamic> toJson() => {
    'space': {'id': spaceId, 'name': name},
    'channels': [for (final c in channels) c.toJson()],
    'categories': [for (final c in categories) c.toJson()],
  };

  SpaceChannel? channel(String id) {
    for (final c in [...channels, for (final k in categories) ...k.channels]) {
      if (c.id == id) return c;
    }
    return null;
  }
}

/// Up to two letters for a Space without an icon (any script).
String spaceInitials(String name) {
  final words = name
      .split(RegExp(r'[\s&]+'))
      .where((w) => w.trim().isNotEmpty)
      .toList();
  if (words.isEmpty) return '?';
  String first(String w) => w.characters.first.toUpperCase();
  return words.length == 1
      ? first(words[0])
      : first(words[0]) + first(words[1]);
}

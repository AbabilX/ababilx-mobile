/// One message in a Space channel (plaintext; Spaces are not E2EE).
class SpaceMessage {
  const SpaceMessage({
    required this.id,
    required this.body,
    this.authorId = '',
    this.authorName = '',
    this.authorAvatar = '',
    this.createdAt,
    this.pending = false,
    this.failed = false,
    this.clientId = '',
  });

  final String id;
  final String body;
  final String authorId;
  final String authorName;
  final String authorAvatar;
  final DateTime? createdAt;

  /// Local only: still sending / could not be sent (kept with Retry).
  final bool pending;
  final bool failed;
  final String clientId;

  static SpaceMessage? fromJson(Object? v) {
    if (v is! Map) return null;
    final id = v['id'];
    if (id is! String || id.isEmpty) return null;
    final a = v['author'];
    String s(Object? x) => x is String ? x : '';
    return SpaceMessage(
      id: id,
      body: s(v['body']),
      authorId: a is Map ? s(a['id']) : '',
      authorName: a is Map ? s(a['name']) : '',
      authorAvatar: a is Map ? s(a['avatar_url']) : '',
      createdAt: DateTime.tryParse(s(v['created_at']))?.toLocal(),
      clientId: s(v['client_id']),
    );
  }

  /// `{messages: [...]}` from GET /v1/channels/:id/messages.
  static List<SpaceMessage> listFromJson(Object? body) {
    final list = body is Map ? body['messages'] : null;
    return [
      if (list is List)
        for (final e in list) ?fromJson(e),
    ];
  }

  /// Cache format: the wire shape. Local-only flags are not stored.
  Map<String, dynamic> toJson() => {
    'id': id,
    'body': body,
    'client_id': clientId,
    'created_at': createdAt?.toUtc().toIso8601String() ?? '',
    'author': {'id': authorId, 'name': authorName, 'avatar_url': authorAvatar},
  };

  SpaceMessage copyWith({bool? pending, bool? failed}) => SpaceMessage(
    id: id,
    body: body,
    authorId: authorId,
    authorName: authorName,
    authorAvatar: authorAvatar,
    createdAt: createdAt,
    pending: pending ?? this.pending,
    failed: failed ?? this.failed,
    clientId: clientId,
  );
}

/// Mirrors the server `models.GroupCall` JSON and web `types/group-call.ts`.
class GroupCall {
  const GroupCall({
    required this.id,
    required this.teamId,
    required this.conversationId,
    required this.startedBy,
    required this.starterName,
    this.starterAvatarUrl,
    this.conversationName,
    required this.status,
    required this.maxParticipants,
    required this.participantCount,
    this.screenSharerId,
    this.screenSharerName,
    required this.startedAt,
    this.endedAt,
    this.endReason,
    this.ring,
  });

  final String id;
  final String teamId;
  final String conversationId;
  final String startedBy;
  final String starterName;
  final String? starterAvatarUrl;
  final String? conversationName;

  /// `starting` · `live` · `ended`
  final String status;
  final int maxParticipants;
  final int participantCount;
  final String? screenSharerId;
  final String? screenSharerName;
  final DateTime startedAt;
  final DateTime? endedAt;
  final String? endReason;

  /// Whether this call rings THIS device's account (server 0172): the starter
  /// may ring only the people they picked. `false` = show the call, stay
  /// quiet. Null = ring, which is every call from a starter who picked no one
  /// and every call from an older server.
  final bool? ring;

  bool get active => status == 'starting' || status == 'live';

  String get title => (conversationName?.trim().isNotEmpty ?? false)
      ? conversationName!
      : 'Group call';

  factory GroupCall.fromJson(Map<String, dynamic> json) => GroupCall(
    id: json['id'] as String? ?? '',
    teamId: json['team_id'] as String? ?? '',
    conversationId: json['conversation_id'] as String? ?? '',
    startedBy: json['started_by'] as String? ?? '',
    starterName: json['starter_name'] as String? ?? 'Someone',
    starterAvatarUrl: _text(json['starter_avatar_url']),
    conversationName: _text(json['conversation_name']),
    status: json['status'] as String? ?? 'live',
    maxParticipants: (json['max_participants'] as num?)?.toInt() ?? 0,
    participantCount: (json['participant_count'] as num?)?.toInt() ?? 0,
    screenSharerId: _text(json['screen_sharer_id']),
    screenSharerName: _text(json['screen_sharer_name']),
    // A missing/unparsable start time must not read as "ancient" — that would
    // silently suppress the ring window in GroupCallInvite.
    startedAt: _date(json['started_at']) ?? DateTime.now(),
    endedAt: _date(json['ended_at']),
    endReason: _text(json['end_reason']),
    ring: json['ring'] is bool ? json['ring'] as bool : null,
  );

  static String? _text(dynamic value) {
    if (value is! String || value.trim().isEmpty) return null;
    return value;
  }

  static DateTime? _date(dynamic value) {
    if (value is! String || value.isEmpty) return null;
    return DateTime.tryParse(value)?.toLocal();
  }
}

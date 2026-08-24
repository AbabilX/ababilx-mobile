/// One past call in the history feed. The server merges 1:1 voice calls and
/// group-call rooms into a single time-ordered list, so this one shape covers
/// both — [kind] says which table it came from.
class CallLogEntry {
  const CallLogEntry({
    required this.id,
    required this.kind,
    required this.scope,
    required this.conversationId,
    required this.mode,
    required this.status,
    required this.direction,
    required this.missed,
    required this.title,
    required this.startedAt,
    this.teamId = '',
    this.peerUserId = '',
    this.avatarUrl,
    this.answeredAt,
    this.endedAt,
    this.durationSec = 0,
  });

  final String id;

  /// `direct` (1:1) or `group`.
  final String kind;

  /// `personal` or `workspace`.
  final String scope;
  final String conversationId;
  final String teamId;

  /// `audio`, `screen` or `group`.
  final String mode;
  final String status;

  /// `incoming` or `outgoing`.
  final String direction;

  /// Incoming, never answered, and not declined on purpose.
  final bool missed;
  final String peerUserId;

  /// Peer name for a direct call, channel name for a group call.
  final String title;
  final String? avatarUrl;
  final DateTime startedAt;
  final DateTime? answeredAt;
  final DateTime? endedAt;
  final int durationSec;

  bool get isGroup => kind == 'group';
  bool get isOutgoing => direction == 'outgoing';
  bool get isScreenShare => mode == 'screen';

  /// Answered at some point, so it has a real duration to show.
  bool get connected => answeredAt != null;

  static DateTime? _date(dynamic v) =>
      v == null ? null : DateTime.tryParse(v as String)?.toLocal();

  factory CallLogEntry.fromJson(Map<String, dynamic> json) => CallLogEntry(
    id: json['id'] as String? ?? '',
    kind: json['kind'] as String? ?? 'direct',
    scope: json['scope'] as String? ?? 'workspace',
    conversationId: json['conversation_id'] as String? ?? '',
    teamId: json['team_id'] as String? ?? '',
    mode: json['mode'] as String? ?? 'audio',
    status: json['status'] as String? ?? '',
    direction: json['direction'] as String? ?? 'incoming',
    missed: json['missed'] as bool? ?? false,
    peerUserId: json['peer_user_id'] as String? ?? '',
    title: json['title'] as String? ?? '',
    avatarUrl: json['avatar_url'] as String?,
    startedAt: _date(json['started_at']) ?? DateTime.now(),
    answeredAt: _date(json['answered_at']),
    endedAt: _date(json['ended_at']),
    durationSec: json['duration_sec'] as int? ?? 0,
  );
}

/// One page of history plus the cursor for the next one.
class CallLogPage {
  const CallLogPage({required this.calls, required this.nextCursor});

  final List<CallLogEntry> calls;
  final String nextCursor;

  factory CallLogPage.fromJson(Map<String, dynamic> json) => CallLogPage(
    calls: (json['calls'] as List<dynamic>? ?? [])
        .map((e) => CallLogEntry.fromJson(e as Map<String, dynamic>))
        .toList(),
    nextCursor: json['next_cursor'] as String? ?? '',
  );
}

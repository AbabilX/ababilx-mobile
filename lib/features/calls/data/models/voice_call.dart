class VoiceCall {
  const VoiceCall({
    required this.id,
    required this.teamId,
    required this.conversationId,
    required this.callerId,
    required this.calleeId,
    required this.status,
    required this.callerName,
    this.callerAvatarUrl,
    required this.calleeName,
    this.calleeAvatarUrl,
    required this.expiresAt,
    this.acceptedAt,
    this.endedAt,
    this.endedBy,
    this.endReason,
    required this.createdAt,
  });

  final String id;
  final String teamId;
  final String conversationId;
  final String callerId;
  final String calleeId;
  final String status;
  final String callerName;
  final String? callerAvatarUrl;
  final String calleeName;
  final String? calleeAvatarUrl;
  final DateTime expiresAt;
  final DateTime? acceptedAt;
  final DateTime? endedAt;
  final String? endedBy;
  final String? endReason;
  final DateTime createdAt;

  bool get isTerminal => const {
    'declined',
    'cancelled',
    'missed',
    'ended',
    'failed',
  }.contains(status);

  String peerName(String currentUserId) =>
      callerId == currentUserId ? calleeName : callerName;

  String? peerAvatar(String currentUserId) =>
      callerId == currentUserId ? calleeAvatarUrl : callerAvatarUrl;

  VoiceCall copyWith({String? status}) => VoiceCall(
    id: id,
    teamId: teamId,
    conversationId: conversationId,
    callerId: callerId,
    calleeId: calleeId,
    status: status ?? this.status,
    callerName: callerName,
    callerAvatarUrl: callerAvatarUrl,
    calleeName: calleeName,
    calleeAvatarUrl: calleeAvatarUrl,
    expiresAt: expiresAt,
    acceptedAt: acceptedAt,
    endedAt: endedAt,
    endedBy: endedBy,
    endReason: endReason,
    createdAt: createdAt,
  );

  factory VoiceCall.fromJson(Map<String, dynamic> json) => VoiceCall(
    id: json['id'] as String? ?? '',
    teamId: json['team_id'] as String? ?? '',
    conversationId: json['conversation_id'] as String? ?? '',
    callerId: json['caller_id'] as String? ?? '',
    calleeId: json['callee_id'] as String? ?? '',
    status: json['status'] as String? ?? 'ringing',
    callerName: json['caller_name'] as String? ?? 'Unknown',
    callerAvatarUrl: json['caller_avatar_url'] as String?,
    calleeName: json['callee_name'] as String? ?? 'Unknown',
    calleeAvatarUrl: json['callee_avatar_url'] as String?,
    expiresAt: DateTime.parse(json['expires_at'] as String).toLocal(),
    acceptedAt: _date(json['accepted_at']),
    endedAt: _date(json['ended_at']),
    endedBy: json['ended_by'] as String?,
    endReason: json['end_reason'] as String?,
    createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
  );

  static DateTime? _date(dynamic value) {
    if (value is! String || value.isEmpty) return null;
    return DateTime.tryParse(value)?.toLocal();
  }
}

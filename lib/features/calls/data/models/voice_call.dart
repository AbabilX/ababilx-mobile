class VoiceCall {
  const VoiceCall({
    required this.id,
    required this.teamId,
    required this.conversationId,
    required this.callerId,
    required this.calleeId,
    required this.status,
    this.mode = 'audio',
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
    this.calleeRingingAt,
    this.callerPrivacy = false,
    this.calleePrivacy = false,
  });

  final String id;
  final String teamId;
  final String conversationId;
  final String callerId;
  final String calleeId;
  final String status;

  /// `audio`, `video` or `screen` — how the call was placed.
  final String mode;
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

  /// First moment a callee device reported it is ringing. The caller says
  /// "Ringing…" from then on instead of "Calling…".
  final DateTime? calleeRingingAt;

  /// That side has privacy mode on (server migration 0152). A private callee
  /// never reports "Ringing…" to the caller, and the OTHER side's phone
  /// blocks screenshots of the call.
  final bool callerPrivacy;
  final bool calleePrivacy;

  /// Whether the person on the other end of this call has privacy mode on.
  bool peerPrivate(String currentUserId) =>
      callerId == currentUserId ? calleePrivacy : callerPrivacy;

  /// The account on the other end of this call.
  String peerId(String currentUserId) =>
      callerId == currentUserId ? calleeId : callerId;

  bool get isTerminal => const {
    'declined',
    'cancelled',
    'missed',
    'ended',
    'failed',
  }.contains(status);

  bool get isVideo => mode == 'video';

  String peerName(String currentUserId) =>
      callerId == currentUserId ? calleeName : callerName;

  String? peerAvatar(String currentUserId) =>
      callerId == currentUserId ? calleeAvatarUrl : callerAvatarUrl;

  VoiceCall copyWith({String? status, DateTime? calleeRingingAt}) => VoiceCall(
    id: id,
    teamId: teamId,
    conversationId: conversationId,
    callerId: callerId,
    calleeId: calleeId,
    status: status ?? this.status,
    mode: mode,
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
    calleeRingingAt: calleeRingingAt ?? this.calleeRingingAt,
    callerPrivacy: callerPrivacy,
    calleePrivacy: calleePrivacy,
  );

  factory VoiceCall.fromJson(Map<String, dynamic> json) => VoiceCall(
    id: json['id'] as String? ?? '',
    teamId: json['team_id'] as String? ?? '',
    conversationId: json['conversation_id'] as String? ?? '',
    callerId: json['caller_id'] as String? ?? '',
    calleeId: json['callee_id'] as String? ?? '',
    status: json['status'] as String? ?? 'ringing',
    mode: json['mode'] as String? ?? 'audio',
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
    calleeRingingAt: _date(json['callee_ringing_at']),
    callerPrivacy: json['caller_privacy'] as bool? ?? false,
    calleePrivacy: json['callee_privacy'] as bool? ?? false,
  );

  static DateTime? _date(dynamic value) {
    if (value is! String || value.isEmpty) return null;
    return DateTime.tryParse(value)?.toLocal();
  }
}

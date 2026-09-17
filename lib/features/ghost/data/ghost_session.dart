import '../../calls/data/models/ice_server.dart';

/// Server end reasons, mirrored from `services/ghostchat`. Every one of them
/// wipes both phones.
abstract final class GhostEndReason {
  static const burn = 'burn';
  static const leave = 'leave';
  static const lost = 'lost';
  static const declined = 'declined';
  static const cancelled = 'cancelled';
}

/// A Ghost Chat session as the server describes it: who invited whom, and the
/// DM key version both phones seal their signals under. It carries no content
/// because the server never has any.
class GhostSession {
  const GhostSession({
    required this.id,
    required this.conversationId,
    required this.inviterId,
    required this.inviteeId,
    required this.status,
    required this.keyVersion,
    this.inviterName = '',
    this.inviterAvatarUrl,
    this.expiresAt,
  });

  final String id;
  final String conversationId;
  final String inviterId;
  final String inviteeId;
  final String status; // pending | active
  final int keyVersion;
  final String inviterName;
  final String? inviterAvatarUrl;
  final DateTime? expiresAt;

  bool get isActive => status == 'active';

  String otherUserId(String self) => self == inviterId ? inviteeId : inviterId;

  factory GhostSession.fromJson(Map<String, dynamic> json) => GhostSession(
    id: json['id'] as String? ?? '',
    conversationId: json['conversation_id'] as String? ?? '',
    inviterId: json['inviter_id'] as String? ?? '',
    inviteeId: json['invitee_id'] as String? ?? '',
    status: json['status'] as String? ?? 'pending',
    keyVersion: (json['key_version'] as num?)?.toInt() ?? 0,
    inviterName: json['inviter_name'] as String? ?? '',
    inviterAvatarUrl: json['inviter_avatar_url'] as String?,
    expiresAt: DateTime.tryParse(json['expires_at'] as String? ?? ''),
  );
}

/// A session plus the ICE servers the server hands out on start and accept.
class GhostSessionGrant {
  const GhostSessionGrant({required this.session, this.iceServers = const []});

  final GhostSession session;
  final List<IceServer> iceServers;

  factory GhostSessionGrant.fromJson(Map<String, dynamic> json) =>
      GhostSessionGrant(
        session: GhostSession.fromJson(
          Map<String, dynamic>.from(json['session'] as Map? ?? const {}),
        ),
        iceServers: [
          for (final raw in json['ice_servers'] as List? ?? const [])
            if (raw is Map) IceServer.fromJson(Map<String, dynamic>.from(raw)),
        ],
      );
}

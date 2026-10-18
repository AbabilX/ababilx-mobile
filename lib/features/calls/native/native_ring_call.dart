import '../data/models/voice_call.dart';

/// Rebuilds the ringing call from the CallKit record the push raised, so the
/// ringing screen can be drawn before the server has been asked anything.
///
/// The record's `extra` is the push itself (`AndroidCallParams._incoming`):
/// id, conversation, caller, picture, expiry and mode — all the ringing
/// screen draws. The server is still the authority and is asked right after;
/// this only stops the screen from waiting on a socket handshake, a token
/// refresh and a lookup before it may appear.
///
/// Null when the record is not a DM ring, is missing what the screen needs,
/// or has already rung out — a CallKit record can outlive its call.
VoiceCall? voiceCallFromNativeRing(
  Map<String, dynamic>? extra, {
  required String id,
  String currentUserId = '',
  DateTime? now,
}) {
  if (extra == null || id.isEmpty) return null;
  if (extra['type']?.toString() != 'voice_call') return null;
  final callId = extra['call_id']?.toString() ?? '';
  if (callId.isNotEmpty && callId != id) return null;
  final conversationId = extra['conversation_id']?.toString() ?? '';
  final callerId = extra['caller_id']?.toString() ?? '';
  if (conversationId.isEmpty || callerId.isEmpty) return null;
  // Our own outgoing record carries no caller and was filtered above; a
  // ring "from" this account would be one anyway.
  if (callerId == currentUserId) return null;
  final expiresAt = DateTime.tryParse(
    extra['expires_at']?.toString() ?? '',
  )?.toLocal();
  final at = now ?? DateTime.now();
  if (expiresAt == null || !expiresAt.isAfter(at)) return null;
  final name = extra['caller_name']?.toString().trim() ?? '';
  final avatar = extra['caller_avatar_url']?.toString().trim() ?? '';
  return VoiceCall(
    id: id,
    teamId: '',
    conversationId: conversationId,
    callerId: callerId,
    calleeId: currentUserId,
    status: 'ringing',
    mode: extra['mode']?.toString() == 'video' ? 'video' : 'audio',
    callerName: name.isEmpty ? 'AbabilX call' : name,
    callerAvatarUrl: avatar.isEmpty ? null : avatar,
    calleeName: '',
    expiresAt: expiresAt,
    createdAt: at,
  );
}

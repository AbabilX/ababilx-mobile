import 'data/models/chat_message.dart';

String _callNoun(String? mode) {
  if (mode == 'screen') return 'screen share';
  if (mode == 'video') return 'video call';
  return 'voice call';
}

String _titleCaseNoun(String noun) =>
    '${noun[0].toUpperCase()}${noun.substring(1)}';

/// Kind line without duration — shared by the single pill and the collapse
/// history rows. Mirrors web `voiceCallKindLabel`.
String voiceCallKindLabel(ChatMessage message, String currentUserId) {
  final meta = message.meta;
  final status = (meta?['status'] as String?) ?? '';
  final callerId = (meta?['caller_id'] as String?) ?? message.userId;
  final isCaller = currentUserId.isNotEmpty && currentUserId == callerId;
  final noun = _callNoun(meta?['mode'] as String?);
  final titled = _titleCaseNoun(noun);

  switch (status) {
    case 'missed':
      return isCaller ? 'No answer' : 'Missed $noun';
    case 'declined':
      return isCaller ? '$titled declined' : 'Declined $noun';
    case 'cancelled':
      // Caller hung up while ringing → callee sees a missed call.
      return isCaller ? 'Cancelled $noun' : 'Missed $noun';
    case 'failed':
      return '$titled failed';
    case 'ended':
      return titled;
    default:
      return message.body.isNotEmpty ? message.body : titled;
  }
}

/// WhatsApp-style label for a voice_call timeline pill, relative to viewer.
String voiceCallMessageLabel(ChatMessage message, String currentUserId) {
  final kind = voiceCallKindLabel(message, currentUserId);
  final status = (message.meta?['status'] as String?) ?? '';
  if (status != 'ended') return kind;
  final durationRaw = message.meta?['duration_seconds'];
  final durationSeconds = durationRaw is num ? durationRaw.toInt() : null;
  final formatted = _formatDuration(durationSeconds);
  return formatted == null ? kind : '$kind · $formatted';
}

/// Expanded call-history line: Incoming/Outgoing, without duration.
/// Mirrors web `voiceCallHistoryLabel`.
String voiceCallHistoryLabel(ChatMessage message, String currentUserId) {
  final status = (message.meta?['status'] as String?) ?? '';
  if (status != 'ended') {
    return voiceCallKindLabel(message, currentUserId);
  }
  final callerId =
      (message.meta?['caller_id'] as String?) ?? message.userId;
  final isCaller = currentUserId.isNotEmpty && currentUserId == callerId;
  final noun = _callNoun(message.meta?['mode'] as String?);
  return isCaller ? 'Outgoing $noun' : 'Incoming $noun';
}

bool isMissedStyleVoiceCall(ChatMessage message, String currentUserId) {
  final meta = message.meta;
  final status = (meta?['status'] as String?) ?? '';
  final callerId = (meta?['caller_id'] as String?) ?? message.userId;
  final isCaller = currentUserId.isNotEmpty && currentUserId == callerId;
  if (status == 'missed') return !isCaller;
  if (status == 'cancelled') return !isCaller;
  if (status == 'declined') return true;
  if (status == 'failed') return true;
  return false;
}

String? _formatDuration(int? totalSeconds) {
  if (totalSeconds == null || totalSeconds <= 0) return null;
  final h = totalSeconds ~/ 3600;
  final m = (totalSeconds % 3600) ~/ 60;
  final s = totalSeconds % 60;
  if (h > 0) {
    return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
  return '$m:${s.toString().padLeft(2, '0')}';
}

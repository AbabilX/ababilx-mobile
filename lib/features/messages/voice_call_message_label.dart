import 'data/models/chat_message.dart';

/// WhatsApp-style label for a voice_call timeline message, relative to viewer.
String voiceCallMessageLabel(ChatMessage message, String currentUserId) {
  final meta = message.meta;
  final status = (meta?['status'] as String?) ?? '';
  final callerId = (meta?['caller_id'] as String?) ?? message.userId;
  final durationRaw = meta?['duration_seconds'];
  final durationSeconds = durationRaw is num ? durationRaw.toInt() : null;
  final isCaller = currentUserId.isNotEmpty && currentUserId == callerId;

  switch (status) {
    case 'missed':
      return isCaller ? 'No answer' : 'Missed voice call';
    case 'declined':
      return isCaller ? 'Voice call declined' : 'Declined voice call';
    case 'cancelled':
      // Caller hung up while ringing → callee sees a missed call.
      return isCaller ? 'Cancelled voice call' : 'Missed voice call';
    case 'failed':
      return 'Voice call failed';
    case 'ended':
      final formatted = _formatDuration(durationSeconds);
      return formatted == null ? 'Voice call' : 'Voice call · $formatted';
    default:
      return message.body.isNotEmpty ? message.body : 'Voice call';
  }
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

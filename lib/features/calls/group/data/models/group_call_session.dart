import 'group_call.dart';

/// Join response: the call row plus the LiveKit credentials for this member.
class GroupCallSession {
  const GroupCallSession({
    required this.call,
    required this.serverUrl,
    required this.participantToken,
  });

  final GroupCall call;
  final String serverUrl;
  final String participantToken;

  factory GroupCallSession.fromJson(Map<String, dynamic> json) {
    final livekit = json['livekit'];
    final creds = livekit is Map
        ? Map<String, dynamic>.from(livekit)
        : const <String, dynamic>{};
    return GroupCallSession(
      call: GroupCall.fromJson(
        Map<String, dynamic>.from(json['call'] as Map? ?? const {}),
      ),
      serverUrl: creds['server_url'] as String? ?? '',
      participantToken: creds['participant_token'] as String? ?? '',
    );
  }
}

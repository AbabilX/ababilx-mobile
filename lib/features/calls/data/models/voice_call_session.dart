import 'ice_server.dart';
import 'voice_call.dart';

class VoiceCallSession {
  const VoiceCallSession({
    required this.call,
    required this.iceServers,
    this.canControl = true,
  });

  final VoiceCall call;
  final bool canControl;
  final List<IceServer> iceServers;

  factory VoiceCallSession.fromJson(Map<String, dynamic> json) =>
      VoiceCallSession(
        canControl: json['can_control'] != false,
        call: VoiceCall.fromJson(
          Map<String, dynamic>.from(json['call'] as Map),
        ),
        iceServers: (json['ice_servers'] as List<dynamic>? ?? const [])
            .map(
              (value) =>
                  IceServer.fromJson(Map<String, dynamic>.from(value as Map)),
            )
            .toList(),
      );
}

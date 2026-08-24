import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import 'models/voice_call_session.dart';

class VoiceCallApi {
  const VoiceCallApi(this._client, {required this.independent});

  final ApiClient _client;
  final bool independent;

  // Older deployed servers still validate these fields. The simple WebRTC
  // client does not use them, but sending a valid placeholder keeps rollout
  // compatibility while server instances are upgraded.
  static const _legacyPublicKey =
      'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=';

  Future<VoiceCallSession> start(String conversationId) async {
    final response = await _client.post(
      independent
          ? ApiConstants.independentChatVoiceCalls(conversationId)
          : ApiConstants.chatVoiceCalls(conversationId),
      data: const {'caller_public_key': _legacyPublicKey},
    );
    return VoiceCallSession.fromJson(
      unwrapApiData<Map<String, dynamic>>(response),
    );
  }

  Future<VoiceCallSession> get(String callId) async {
    final response = await _client.get(ApiConstants.chatVoiceCall(callId));
    return VoiceCallSession.fromJson(
      unwrapApiData<Map<String, dynamic>>(response),
    );
  }

  Future<VoiceCallSession> action(
    String callId,
    String action, {
    String? reason,
  }) async {
    final response = await _client.post(
      ApiConstants.chatVoiceCallActions(callId),
      data: {
        'action': action,
        if (action == 'accept') 'callee_public_key': _legacyPublicKey,
        'reason': ?reason,
      },
    );
    return VoiceCallSession.fromJson(
      unwrapApiData<Map<String, dynamic>>(response),
    );
  }
}

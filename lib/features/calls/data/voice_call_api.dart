import 'package:dio/dio.dart';

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

  Future<VoiceCallSession> start(
    String conversationId, {
    String mode = 'audio',
  }) async {
    final response = await _client.post(
      independent
          ? ApiConstants.independentChatVoiceCalls(conversationId)
          : ApiConstants.chatVoiceCalls(conversationId),
      data: {'caller_public_key': _legacyPublicKey, 'mode': mode},
    );
    return VoiceCallSession.fromJson(
      unwrapApiData<Map<String, dynamic>>(response),
    );
  }

  /// The account's current live call, or null.
  ///
  /// Recovery path for a call this device no longer knows the id of — a killed
  /// process, or a drop that took the network with it. Without it a row the
  /// server still believes in is unreachable: every new call is refused as
  /// busy and there is nothing to point the hangup at. A 404 means the server
  /// predates the endpoint, which is not an error worth surfacing.
  Future<VoiceCallSession?> activeCall() async {
    try {
      final response = await _client.get(ApiConstants.meActiveCall);
      final data = unwrapApiData<Map<String, dynamic>>(response);
      if (data['call'] == null) return null;
      return VoiceCallSession.fromJson(data);
    } on DioException catch (error) {
      if (error.response?.statusCode == 404) return null;
      rethrow;
    }
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

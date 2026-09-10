import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';

class ChatRecoveryApi {
  const ChatRecoveryApi(this._client);
  final ApiClient _client;
  Future<void> startSession(Map<String, dynamic> body) =>
      _client.post(ApiConstants.chatRecoverySession, data: body);
  Future<Map<String, dynamic>> challenge() async =>
      unwrapApiData<Map<String, dynamic>>(
        await _client.post(ApiConstants.chatRecoveryChallenge),
      );
  Future<Map<String, dynamic>> verify(String challenge, String code) async =>
      unwrapApiData<Map<String, dynamic>>(
        await _client.post(
          ApiConstants.chatRecoveryVerify,
          data: {'challenge_id': challenge, 'code': code},
        ),
      );
}

final chatRecoveryApiProvider = Provider(
  (ref) => ChatRecoveryApi(ref.watch(apiClientProvider)),
);

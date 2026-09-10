import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';

class ChatRecoveryApi {
  const ChatRecoveryApi(this._client);
  final ApiClient _client;
  Future<void> startSession(Map<String, dynamic> body) =>
      _client.post(ApiConstants.chatRecoverySession, data: body);
}

final chatRecoveryApiProvider = Provider(
  (ref) => ChatRecoveryApi(ref.watch(apiClientProvider)),
);

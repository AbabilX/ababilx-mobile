import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/recent_sign_in.dart';
import '../../auth/reauth/recent_sign_in.dart';

class ChatRecoveryApi {
  const ChatRecoveryApi(this._client, [this._reauthenticate]);
  final ApiClient _client;
  final Future<ReauthOutcome> Function()? _reauthenticate;

  /// Replacing an established identity needs a recent sign-in. When the
  /// server says so, this phone signs in again for real and sends the SAME
  /// body once more; the sign-in itself touches no identity. Anything still
  /// refused surfaces as [RecentSignInRequired].
  Future<void> startSession(Map<String, dynamic> body) => withRecentSignIn(
    request: () => _client.post(ApiConstants.chatRecoverySession, data: body),
    reauthenticate: _reauthenticate ?? () async => ReauthOutcome.notSupported,
  );
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
  (ref) => ChatRecoveryApi(
    ref.watch(apiClientProvider),
    ref.read(recentSignInProvider).reauthenticate,
  ),
);

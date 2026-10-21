import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';

/// The receiving half of `/api/chat/e2ee/push/*` (server 0182). The computer
/// creates, polls and approves; this phone offers its key and waits.
class ComputerLinkApi {
  const ComputerLinkApi(this._client);
  final ApiClient _client;

  /// 410 `link_expired` when the code is gone, already taken, or another
  /// account's — deliberately one answer for all three.
  Future<void> offer(
    String token,
    Map<String, dynamic> publicJwk,
    String mac,
    String deviceName,
  ) => _client.post(
    ApiConstants.chatE2eePushOffer,
    data: {
      'token': token,
      'device_name': deviceName,
      'receiver_key': {'public_key': publicJwk, 'mac': mac},
    },
  );

  /// `{status: pending|approved|denied|expired, identity_envelope?}`.
  Future<Map<String, dynamic>> receive(String token) async {
    final res = await _client.post(
      ApiConstants.chatE2eePushReceive,
      data: {'token': token},
    );
    return unwrapApiData<Map<String, dynamic>>(res);
  }

  Future<void> deny(String token) =>
      _client.post(ApiConstants.chatE2eePushDeny, data: {'token': token});
}

final computerLinkApiProvider = Provider<ComputerLinkApi>(
  (ref) => ComputerLinkApi(ref.watch(apiClientProvider)),
);

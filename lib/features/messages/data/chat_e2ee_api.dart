import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import 'chat_endpoints.dart';

class ChatE2eeApi {
  const ChatE2eeApi(this._client, this._endpoints);
  final ApiClient _client;
  final ChatEndpoints _endpoints;

  Future<Map<String, dynamic>> getVault() async {
    final res = await _client.get(ApiConstants.chatE2eeVault);
    return unwrapApiData<Map<String, dynamic>>(res);
  }

  Future<void> putVault(Map<String, dynamic> data) =>
      _client.put(ApiConstants.chatE2eeVault, data: data);

  /// Publishes a device-local identity: the public key and nothing else. The
  /// private half is generated on this phone and never leaves it, which is why
  /// there is no PIN to choose.
  Future<void> putIdentity(Map<String, dynamic> publicJwk) =>
      _client.put(ApiConstants.chatE2eeVault, data: {'public_key': publicJwk});

  Future<void> deleteWrappedKey() =>
      _client.delete(ApiConstants.chatE2eeWrappedKey);

  /// Publishes the identity with its private key wrapped by a recovery code,
  /// or re-wraps the same identity under a newly generated one. The code itself
  /// never appears in this request.
  Future<void> putRecoveryVault(
    Map<String, dynamic> publicJwk,
    Map<String, dynamic> recovery,
  ) => _client.put(
    ApiConstants.chatE2eeRecoveryVault,
    data: {'public_key': publicJwk, ...recovery},
  );

  /// Asks for the emailed code that authorises replacing this account's
  /// identity. Returns the masked address it went to, so the user knows which
  /// inbox to open.
  Future<Map<String, dynamic>> requestResetCode() async {
    final res = await _client.post(ApiConstants.chatE2eeResetCode);
    return unwrapApiData<Map<String, dynamic>>(res);
  }

  /// Swaps in a freshly minted identity. The emailed code authorises the swap;
  /// it unlocks nothing old, because nobody holds that key any more.
  ///
  /// The new identity's recovery copy travels in the same request: leaving it
  /// stranded on one device would recreate the situation the reset exists to
  /// escape, and the emailed code has already been spent by then.
  Future<void> resetVault(
    String code,
    Map<String, dynamic> publicJwk,
    Map<String, dynamic> recovery,
  ) async {
    // Older servers silently ignore clear_history. Refuse before replacing
    // anything, instead of promising an empty account then reloading old chats.
    final status = await getVault();
    if (status['supports_fresh_start'] != true) {
      throw StateError('Fresh start requires an updated server');
    }
    final response = await _client.post(
      ApiConstants.chatE2eeReset,
      data: {
        'code': code, 'public_key': publicJwk,
        'recovery': recovery, 'clear_history': true,
      },
    );
    final data = unwrapApiData<Map<String, dynamic>>(response);
    if (data['history_cleared'] != true) {
      throw StateError('The server did not confirm clearing message history');
    }
  }

  Future<Map<String, dynamic>> createLink(String deviceName) async {
    final res = await _client.post(
      ApiConstants.chatE2eeLink,
      data: {'device_name': deviceName},
    );
    return unwrapApiData<Map<String, dynamic>>(res);
  }

  Future<Map<String, dynamic>> inspectLink(String token) async {
    final res = await _client.post(
      ApiConstants.chatE2eeLinkInfo,
      data: {'token': token},
    );
    return unwrapApiData<Map<String, dynamic>>(res);
  }

  Future<void> approveLink(String token, Map<String, dynamic> envelope) =>
      _client.post(
        ApiConstants.chatE2eeLinkApprove,
        data: {'token': token, 'identity_envelope': envelope},
      );

  Future<void> denyLink(String token) =>
      _client.post(ApiConstants.chatE2eeLinkDeny, data: {'token': token});

  /// `{status, identity_envelope?}` — nested under `data` like every other
  /// endpoint. It was briefly returned at the top level, which made the web
  /// client (which always unwraps) read `status` off `undefined`.
  Future<Map<String, dynamic>> pollLink(String token) async {
    final res = await _client.post(
      ApiConstants.chatE2eeLinkPoll,
      data: {'token': token},
    );
    return unwrapApiData<Map<String, dynamic>>(res);
  }

  Future<Map<String, dynamic>> getPublicKey(String userId) async {
    final res = await _client.get(_endpoints.publicKey(userId));
    return unwrapApiData<Map<String, dynamic>>(res);
  }

  Future<Map<String, dynamic>> getConversationKey(String conversationId) async {
    final res = await _client.get(
      _endpoints.action(conversationId, 'e2ee-key'),
    );
    return unwrapApiData<Map<String, dynamic>>(res);
  }

  /// Every member of a conversation with the public identity a key must be
  /// sealed to, plus `unready_member_ids` — members with no identity at all.
  ///
  /// A DM could work from peer_user_id and one public-key fetch; a group cannot,
  /// and asking per member would be one request per person on every rotation.
  Future<Map<String, dynamic>> getConversationMembers(
    String conversationId,
  ) async {
    final res = await _client.get(
      _endpoints.action(conversationId, 'e2ee-members'),
    );
    return unwrapApiData<Map<String, dynamic>>(res);
  }

  Future<Map<String, dynamic>> createConversationKey(
    String conversationId,
    Map<String, dynamic> envelopes,
  ) async {
    final res = await _client.post(
      _endpoints.action(conversationId, 'e2ee-key'),
      data: {'envelopes': envelopes},
    );
    return unwrapApiData<Map<String, dynamic>>(res);
  }

  /// Hands existing conversation keys to members who cannot read them, after
  /// they started a fresh identity. Each entry is
  /// `{user_id, key_version, envelope}`, already sealed to that member's
  /// public identity.
  Future<Map<String, dynamic>> backfillConversationKey(
    String conversationId,
    List<Map<String, dynamic>> envelopes,
  ) async {
    final res = await _client.post(
      _endpoints.action(conversationId, 'e2ee-key/backfill'),
      data: {'envelopes': envelopes},
    );
    return unwrapApiData<Map<String, dynamic>>(res);
  }
}

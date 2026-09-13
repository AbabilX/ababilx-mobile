import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import 'chat_e2ee_api.dart';
import 'chat_endpoints.dart';

/// Reading and repairing message history across key rotations.
///
/// Kept apart from [ChatE2eeApi], which is the send side's contract — the
/// identity, the newest key and rotation — because these calls exist for the
/// messages already written: fetching the exact key version one was sealed
/// under, and handing a broken envelope back to the repair machinery.
class ChatE2eeHistoryApi {
  const ChatE2eeHistoryApi(this._client, this._endpoints);
  final ApiClient _client;
  final ChatEndpoints _endpoints;

  /// This account's own envelopes at exactly [versions], as
  /// `{envelopes: [{key_version, envelope}]}`. A version it holds none for is
  /// absent from the list.
  ///
  /// [ChatE2eeApi.getConversationKey] returns the newest version only, which is what a
  /// send needs. A message sealed before a rotation needs the version it was
  /// sealed under, and this is the only place the server hands a retired one
  /// back.
  Future<Map<String, dynamic>> getConversationKeyVersions(
    String conversationId,
    List<int> versions,
  ) async {
    final res = await _client.get(
      _endpoints.action(conversationId, 'e2ee-keys'),
      queryParameters: {'versions': versions.join(',')},
    );
    return unwrapApiData<Map<String, dynamic>>(res);
  }

  /// Tells the server this account's envelope at [keyVersion] does not open
  /// under [publicJwk], the identity this device holds. `{removed: bool}` —
  /// the server drops the row only while [publicJwk] is still the account's
  /// published identity, which hands the version to the ordinary rotation and
  /// backfill repairs.
  Future<Map<String, dynamic>> reportUnreadableEnvelope(
    String conversationId,
    int keyVersion,
    Map<String, dynamic> publicJwk,
  ) async {
    final res = await _client.post(
      _endpoints.action(conversationId, 'e2ee-key/unreadable'),
      data: {'key_version': keyVersion, 'public_key': publicJwk},
    );
    return unwrapApiData<Map<String, dynamic>>(res);
  }

  /// `{conversation_ids: [...]}` — where this account can give another member
  /// a key version they lost, without opening each conversation to find out.
  Future<Map<String, dynamic>> getFillableGaps() async {
    final res = await _client.get(ApiConstants.chatE2eeFillableGaps);
    return unwrapApiData<Map<String, dynamic>>(res);
  }
}

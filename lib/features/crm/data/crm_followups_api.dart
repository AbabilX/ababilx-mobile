import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import 'models/crm_models.dart';

class CrmFollowupsApi {
  const CrmFollowupsApi(this._client);
  final ApiClient _client;

  Future<List<CrmFollowup>> list({String? leadId}) async {
    final res = await _client.get(
      ApiConstants.crmFollowups,
      queryParameters: {
        if (leadId != null && leadId.isNotEmpty) 'lead_id': leadId,
      },
    );
    final raw = unwrapApiData<dynamic>(res);
    if (raw is! List) return const [];
    return [
      for (final e in raw)
        CrmFollowup.fromJson(Map<String, dynamic>.from(e as Map)),
    ];
  }

  Future<CrmFollowup> create(CrmFollowupInput body) async {
    final res = await _client.post(
      ApiConstants.crmFollowups,
      data: body.toJson(),
    );
    return CrmFollowup.fromJson(unwrapApiData<Map<String, dynamic>>(res));
  }

  Future<CrmFollowup> patch(String id, CrmFollowupPatch body) async {
    final res = await _client.patch(
      ApiConstants.crmFollowup(id),
      data: body.toJson(),
    );
    return CrmFollowup.fromJson(unwrapApiData<Map<String, dynamic>>(res));
  }

  Future<void> delete(String id) async {
    await _client.delete(ApiConstants.crmFollowup(id));
  }
}

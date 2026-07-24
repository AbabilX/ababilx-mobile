import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import 'models/crm_models.dart';

class CrmLeadsApi {
  const CrmLeadsApi(this._client);
  final ApiClient _client;

  Future<List<CrmLead>> list({String? q, String? contactId}) async {
    final res = await _client.get(
      ApiConstants.crmLeads,
      queryParameters: {
        if (q != null && q.isNotEmpty) 'q': q,
        if (contactId != null && contactId.isNotEmpty) 'contact_id': contactId,
      },
    );
    final raw = unwrapApiData<dynamic>(res);
    if (raw is! List) return const [];
    return [
      for (final e in raw)
        CrmLead.fromJson(Map<String, dynamic>.from(e as Map)),
    ];
  }

  Future<CrmLead> create(String contactId, CrmLeadInput body) async {
    final res = await _client.post(
      ApiConstants.crmContactLeads(contactId),
      data: body.toJson(),
    );
    return CrmLead.fromJson(unwrapApiData<Map<String, dynamic>>(res));
  }

  Future<CrmLead> update(String id, CrmLeadInput body) async {
    final res = await _client.patch(
      ApiConstants.crmLead(id),
      data: body.toJson(),
    );
    return CrmLead.fromJson(unwrapApiData<Map<String, dynamic>>(res));
  }

  Future<void> delete(String id) async {
    await _client.delete(ApiConstants.crmLead(id));
  }
}

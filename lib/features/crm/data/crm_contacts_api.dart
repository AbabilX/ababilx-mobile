import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import 'models/crm_models.dart';

class CrmContactsApi {
  const CrmContactsApi(this._client);
  final ApiClient _client;

  Future<List<CrmContact>> list({String? ownerId, String? q}) async {
    final res = await _client.get(
      ApiConstants.crmContacts,
      queryParameters: {
        if (ownerId != null && ownerId.isNotEmpty) 'owner_id': ownerId,
        if (q != null && q.isNotEmpty) 'q': q,
      },
    );
    final raw = unwrapApiData<dynamic>(res);
    if (raw is! List) return const [];
    return [
      for (final e in raw)
        CrmContact.fromJson(Map<String, dynamic>.from(e as Map)),
    ];
  }

  Future<CrmContact> get(String id) async {
    final res = await _client.get(ApiConstants.crmContact(id));
    return CrmContact.fromJson(unwrapApiData<Map<String, dynamic>>(res));
  }

  Future<CrmContact> create(CrmContactInput body) async {
    final res = await _client.post(
      ApiConstants.crmContacts,
      data: body.toJson(),
    );
    return CrmContact.fromJson(unwrapApiData<Map<String, dynamic>>(res));
  }

  Future<CrmContact> update(String id, CrmContactInput body) async {
    final res = await _client.patch(
      ApiConstants.crmContact(id),
      data: body.toJson(),
    );
    return CrmContact.fromJson(unwrapApiData<Map<String, dynamic>>(res));
  }

  Future<void> delete(String id) async {
    await _client.delete(ApiConstants.crmContact(id));
  }
}

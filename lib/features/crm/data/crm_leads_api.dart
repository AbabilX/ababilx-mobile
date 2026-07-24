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

  Future<CrmLead> get(String id) async {
    final res = await _client.get(ApiConstants.crmLead(id));
    return CrmLead.fromJson(unwrapApiData<Map<String, dynamic>>(res));
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

  Future<CrmLead> updateStage(
    String id, {
    required String stageId,
    String? pipelineId,
  }) async {
    final res = await _client.patch(
      ApiConstants.crmLeadStage(id),
      data: {
        'stage_id': stageId,
        'pipeline_id': pipelineId,
      },
    );
    return CrmLead.fromJson(unwrapApiData<Map<String, dynamic>>(res));
  }

  Future<void> delete(String id) async {
    await _client.delete(ApiConstants.crmLead(id));
  }

  Future<List<CrmTimelineEvent>> timeline(String id) async {
    final res = await _client.get(ApiConstants.crmLeadTimeline(id));
    final raw = unwrapApiData<dynamic>(res);
    if (raw is! List) return const [];
    return [
      for (final e in raw)
        CrmTimelineEvent.fromJson(Map<String, dynamic>.from(e as Map)),
    ];
  }

  Future<List<CrmNote>> listNotes(String leadId) async {
    final res = await _client.get(ApiConstants.crmLeadNotes(leadId));
    final raw = unwrapApiData<dynamic>(res);
    if (raw is! List) return const [];
    return [
      for (final e in raw)
        CrmNote.fromJson(Map<String, dynamic>.from(e as Map)),
    ];
  }

  Future<CrmNote> createNote(String leadId, String body) async {
    final res = await _client.post(
      ApiConstants.crmLeadNotes(leadId),
      data: {'body': body},
    );
    return CrmNote.fromJson(unwrapApiData<Map<String, dynamic>>(res));
  }

  Future<void> deleteNote(String noteId) async {
    await _client.delete(ApiConstants.crmNote(noteId));
  }

  Future<List<CrmActivity>> listActivities(String leadId) async {
    final res = await _client.get(ApiConstants.crmLeadActivities(leadId));
    final raw = unwrapApiData<dynamic>(res);
    if (raw is! List) return const [];
    return [
      for (final e in raw)
        CrmActivity.fromJson(Map<String, dynamic>.from(e as Map)),
    ];
  }

  Future<CrmActivity> createActivity(
    String leadId,
    CrmActivityInput body,
  ) async {
    final res = await _client.post(
      ApiConstants.crmLeadActivities(leadId),
      data: body.toJson(),
    );
    return CrmActivity.fromJson(unwrapApiData<Map<String, dynamic>>(res));
  }
}

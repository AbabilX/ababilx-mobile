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

  /// Web `commitCRMLeadStageTransition` — requires `occurred_at`.
  Future<CrmLead> commitStageTransition(
    String id, {
    required String stageId,
    required String pipelineId,
    required String occurredAt,
    String? description,
    String? note,
    List<String> uploadIds = const [],
  }) async {
    final res = await _client.patch(
      ApiConstants.crmLeadStage(id),
      data: {
        'stage_id': stageId,
        'pipeline_id': pipelineId,
        'occurred_at': occurredAt,
        if (description != null && description.isNotEmpty)
          'description': description,
        if (note != null && note.isNotEmpty) 'note': note,
        if (uploadIds.isNotEmpty) 'upload_ids': uploadIds,
      },
    );
    final data = unwrapApiData<Map<String, dynamic>>(res);
    // API returns `{ lead, event }` or sometimes the lead itself.
    if (data['lead'] is Map) {
      return CrmLead.fromJson(Map<String, dynamic>.from(data['lead'] as Map));
    }
    return CrmLead.fromJson(data);
  }

  Future<({String uploadId, String uploadUrl})> presignStageUpload(
    String leadId, {
    required String targetStageId,
    required String contentType,
    required String fileName,
    required int sizeBytes,
  }) async {
    final res = await _client.post(
      ApiConstants.crmLeadStageUploadsPresign(leadId),
      data: {
        'target_stage_id': targetStageId,
        'content_type': contentType,
        'file_name': fileName,
        'size_bytes': sizeBytes,
      },
    );
    final data = unwrapApiData<Map<String, dynamic>>(res);
    return (
      uploadId: data['upload_id'] as String? ?? '',
      uploadUrl: data['upload_url'] as String? ?? '',
    );
  }

  Future<void> discardStageUpload(String uploadId) async {
    await _client.delete(ApiConstants.crmStageUpload(uploadId));
  }

  @Deprecated('Use commitStageTransition')
  Future<CrmLead> updateStage(
    String id, {
    required String stageId,
    String? pipelineId,
  }) async {
    return commitStageTransition(
      id,
      stageId: stageId,
      pipelineId: pipelineId ?? '',
      occurredAt: DateTime.now().toUtc().toIso8601String(),
    );
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

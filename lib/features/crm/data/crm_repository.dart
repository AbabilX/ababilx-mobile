import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import 'crm_config_api.dart';
import 'crm_contact_media_api.dart';
import 'crm_contacts_api.dart';
import 'crm_dashboard_api.dart';
import 'crm_documents_api.dart';
import 'crm_followups_api.dart';
import 'crm_leads_api.dart';
import 'models/crm_dashboard.dart';
import 'models/crm_models.dart';

class CrmRepository {
  CrmRepository(ApiClient client)
      : contacts = CrmContactsApi(client),
        contactMedia = CrmContactMediaApi(client),
        leads = CrmLeadsApi(client),
        followups = CrmFollowupsApi(client),
        documents = CrmDocumentsApi(client),
        dashboard = CrmDashboardApi(client),
        config = CrmConfigApi(client);

  final CrmContactsApi contacts;
  final CrmContactMediaApi contactMedia;
  final CrmLeadsApi leads;
  final CrmFollowupsApi followups;
  final CrmDocumentsApi documents;
  final CrmDashboardApi dashboard;
  final CrmConfigApi config;

  Future<List<CrmContact>> listContacts({String? q}) => contacts.list(q: q);

  Future<CrmContact> getContact(String id) => contacts.get(id);

  Future<List<CrmLead>> listContactLeads(String contactId) =>
      leads.list(contactId: contactId);

  Future<CrmContact> createContact(CrmContactInput body) =>
      contacts.create(body);

  Future<CrmContact> updateContact(String id, CrmContactInput body) =>
      contacts.update(id, body);

  Future<void> deleteContact(String id) => contacts.delete(id);

  Future<String> uploadContactImage({
    required List<int> bytes,
    required String contentType,
  }) =>
      contactMedia.upload(bytes: bytes, contentType: contentType);

  Future<void> discardContactImage(String imageUrl) =>
      contactMedia.discard(imageUrl);

  Future<List<CrmLead>> listLeads({String? q, String? contactId}) =>
      leads.list(q: q, contactId: contactId);

  Future<CrmLead> getLead(String id) => leads.get(id);

  Future<CrmLead> createLead(String contactId, CrmLeadInput body) =>
      leads.create(contactId, body);

  Future<CrmLead> updateLead(String id, CrmLeadInput body) =>
      leads.update(id, body);

  Future<CrmLead> commitLeadStageTransition(
    String id, {
    required String stageId,
    required String pipelineId,
    required String occurredAt,
    String? description,
    String? note,
    List<String> uploadIds = const [],
  }) =>
      leads.commitStageTransition(
        id,
        stageId: stageId,
        pipelineId: pipelineId,
        occurredAt: occurredAt,
        description: description,
        note: note,
        uploadIds: uploadIds,
      );

  Future<({String uploadId, String uploadUrl})> presignStageUpload(
    String leadId, {
    required String targetStageId,
    required String contentType,
    required String fileName,
    required int sizeBytes,
  }) =>
      leads.presignStageUpload(
        leadId,
        targetStageId: targetStageId,
        contentType: contentType,
        fileName: fileName,
        sizeBytes: sizeBytes,
      );

  Future<void> discardStageUpload(String uploadId) =>
      leads.discardStageUpload(uploadId);

  Future<CrmLead> updateLeadStage(
    String id, {
    required String stageId,
    String? pipelineId,
  }) =>
      leads.updateStage(id, stageId: stageId, pipelineId: pipelineId);

  Future<void> deleteLead(String id) => leads.delete(id);

  Future<List<CrmTimelineEvent>> leadTimeline(String id) => leads.timeline(id);

  Future<List<CrmNote>> listNotes(String leadId) => leads.listNotes(leadId);

  Future<CrmNote> createNote(String leadId, String body) =>
      leads.createNote(leadId, body);

  Future<void> deleteNote(String noteId) => leads.deleteNote(noteId);

  Future<List<CrmActivity>> listActivities(String leadId) =>
      leads.listActivities(leadId);

  Future<CrmActivity> createActivity(String leadId, CrmActivityInput body) =>
      leads.createActivity(leadId, body);

  Future<List<CrmFollowup>> listFollowups({String? leadId}) =>
      followups.list(leadId: leadId);

  Future<CrmFollowup> createFollowup(CrmFollowupInput body) =>
      followups.create(body);

  Future<CrmFollowup> patchFollowup(String id, CrmFollowupPatch body) =>
      followups.patch(id, body);

  Future<void> deleteFollowup(String id) => followups.delete(id);

  Future<int> bulkFollowups({
    required List<String> ids,
    required String action,
    String? assignedUserId,
  }) =>
      followups.bulk(
        ids: ids,
        action: action,
        assignedUserId: assignedUserId,
      );

  Future<List<CrmDocument>> listDocuments(String leadId) =>
      documents.list(leadId);

  Future<CrmDocument> uploadDocument(
    String leadId, {
    required List<int> bytes,
    required String fileName,
    required String mimeType,
    String? label,
  }) =>
      documents.upload(
        leadId,
        bytes: bytes,
        fileName: fileName,
        mimeType: mimeType,
        label: label,
      );

  Future<void> deleteDocument(String docId) => documents.delete(docId);

  Future<CrmConfig> getConfig() => config.get();

  Future<CrmDashboard> getDashboard() => dashboard.get();
}

final crmRepositoryProvider = Provider<CrmRepository>(
  (ref) => CrmRepository(ref.watch(apiClientProvider)),
);

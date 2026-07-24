import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/crm_repository.dart';
import '../data/models/crm_models.dart';
import 'crm_leads_provider.dart';
import 'crm_leads_ui_provider.dart';

final crmLeadProvider =
    FutureProvider.family<CrmLead, String>((ref, leadId) {
  return ref.watch(crmRepositoryProvider).getLead(leadId);
});

final crmLeadTimelineProvider =
    FutureProvider.family<List<CrmTimelineEvent>, String>((ref, leadId) {
  return ref.watch(crmRepositoryProvider).leadTimeline(leadId);
});

final crmLeadNotesProvider =
    FutureProvider.family<List<CrmNote>, String>((ref, leadId) {
  return ref.watch(crmRepositoryProvider).listNotes(leadId);
});

final crmLeadActivitiesProvider =
    FutureProvider.family<List<CrmActivity>, String>((ref, leadId) {
  return ref.watch(crmRepositoryProvider).listActivities(leadId);
});

final crmLeadFollowupsProvider =
    FutureProvider.family<List<CrmFollowup>, String>((ref, leadId) {
  return ref.watch(crmRepositoryProvider).listFollowups(leadId: leadId);
});

final crmLeadDocumentsProvider =
    FutureProvider.family<List<CrmDocument>, String>((ref, leadId) {
  return ref.watch(crmRepositoryProvider).listDocuments(leadId);
});

void invalidateLeadDetail(WidgetRef ref, String leadId) {
  ref.invalidate(crmLeadProvider(leadId));
  ref.invalidate(crmLeadTimelineProvider(leadId));
  ref.invalidate(crmLeadNotesProvider(leadId));
  ref.invalidate(crmLeadActivitiesProvider(leadId));
  ref.invalidate(crmLeadFollowupsProvider(leadId));
  ref.invalidate(crmLeadDocumentsProvider(leadId));
  final q = ref.read(crmLeadsUiProvider).searchQuery;
  ref.invalidate(crmLeadsProvider(q));
}

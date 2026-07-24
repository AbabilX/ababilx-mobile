import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/crm_repository.dart';
import '../data/models/crm_models.dart';

final crmContactProvider =
    FutureProvider.family<CrmContact, String>((ref, id) {
  return ref.watch(crmRepositoryProvider).getContact(id);
});

final crmContactLeadsProvider =
    FutureProvider.family<List<CrmLead>, String>((ref, contactId) {
  return ref.watch(crmRepositoryProvider).listContactLeads(contactId);
});

void invalidateContactDetail(WidgetRef ref, String contactId) {
  ref.invalidate(crmContactProvider(contactId));
  ref.invalidate(crmContactLeadsProvider(contactId));
}

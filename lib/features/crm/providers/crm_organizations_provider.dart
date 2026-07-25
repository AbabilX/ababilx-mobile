import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/crm_repository.dart';
import '../data/models/crm_models.dart';

final crmOrganizationsProvider =
    FutureProvider.family<List<CrmOrganization>, String>((ref, query) {
      return ref.watch(crmRepositoryProvider).listOrganizations(q: query);
    });

final crmOrganizationProvider = FutureProvider.family<CrmOrganization, String>((
  ref,
  id,
) {
  return ref.watch(crmRepositoryProvider).getOrganization(id);
});

final crmOrganizationContactsProvider =
    FutureProvider.family<List<CrmContact>, String>((ref, id) {
      return ref.watch(crmRepositoryProvider).listContacts(organizationId: id);
    });

final crmOrganizationLeadsProvider =
    FutureProvider.family<List<CrmLead>, String>((ref, id) {
      return ref.watch(crmRepositoryProvider).listLeads(organizationId: id);
    });

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/crm_repository.dart';
import '../data/models/crm_models.dart';

final crmConfigProvider = FutureProvider<CrmConfig>((ref) {
  return ref.watch(crmRepositoryProvider).getConfig();
});

/// Contacts list — refetch when [q] changes (mirrors web useCRMContacts).
final crmContactsProvider =
    FutureProvider.family<List<CrmContact>, String>((ref, q) {
  return ref.watch(crmRepositoryProvider).listContacts(
        q: q.isEmpty ? null : q,
      );
});

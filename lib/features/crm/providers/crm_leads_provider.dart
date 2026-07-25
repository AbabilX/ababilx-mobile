import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/crm_repository.dart';
import '../data/models/crm_models.dart';

/// Leads list — refetch when [q] changes (mirrors web useCRMLeads).
final crmLeadsProvider = FutureProvider.family<List<CrmLead>, String>((ref, q) {
  return ref.watch(crmRepositoryProvider).listLeads(q: q.isEmpty ? null : q);
});

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/crm_repository.dart';
import '../data/models/crm_models.dart';

final crmFollowupsProvider = FutureProvider.family<List<CrmFollowup>, String>((
  ref,
  q,
) {
  return ref.watch(crmRepositoryProvider).listFollowups();
});

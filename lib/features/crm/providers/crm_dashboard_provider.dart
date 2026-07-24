import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/crm_repository.dart';
import '../data/models/crm_dashboard.dart';

final crmDashboardProvider = FutureProvider<CrmDashboard>((ref) {
  return ref.watch(crmRepositoryProvider).getDashboard();
});

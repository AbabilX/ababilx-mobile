import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../crm/data/models/crm_models.dart';
import '../../team/data/models/team_models.dart';
import '../../team/data/team_repository.dart';

final teamGateProvider = FutureProvider<TeamDetail?>((ref) async {
  return ref.watch(teamRepositoryProvider).getMyTeam();
});

final hasTeamProvider = Provider<bool>((ref) {
  final team = ref.watch(teamGateProvider);
  return team.maybeWhen(data: (d) => d?.hasTeam ?? false, orElse: () => false);
});

final teamMembersProvider = Provider<List<TeamMember>>((ref) {
  final team = ref.watch(teamGateProvider);
  return team.maybeWhen(
    data: (d) => d?.members.where((m) => m.status == 'active').toList() ?? [],
    orElse: () => [],
  );
});

/// Web-parity CRM entry gate: `team_is_premium && crm_access`.
final canViewCrmProvider = Provider<bool>((ref) {
  final team = ref.watch(teamGateProvider);
  return team.maybeWhen(
    data: (d) => d?.canViewCrm ?? false,
    orElse: () => false,
  );
});

/// Fine-grained CRM actions (create/update/delete/configure).
final crmPermsProvider = Provider<CrmPerms>((ref) {
  final team = ref.watch(teamGateProvider);
  return team.maybeWhen(
    data: (d) => d?.crmPerms ?? CrmPerms.none,
    orElse: () => CrmPerms.none,
  );
});

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../crm/data/models/crm_models.dart';
import '../../team/data/models/team_models.dart';
import '../../team/data/team_repository.dart';

/// The team gate behind Messages, CRM, Wall and Board.
///
/// WhatsApp-style: paint the cached team immediately so those tabs never
/// block cold-opening the app on the network, then refresh in the background.
class TeamGateNotifier extends AsyncNotifier<TeamDetail?> {
  @override
  Future<TeamDetail?> build() async {
    final repo = ref.watch(teamRepositoryProvider);
    final cached = await repo.getCachedTeam();
    if (cached != null) {
      unawaited(_refreshInBackground(repo));
      return cached;
    }
    // First-ever load, nothing cached yet: this has to wait on the network.
    return repo.getMyTeam();
  }

  Future<void> _refreshInBackground(TeamRepository repo) async {
    try {
      final fresh = await repo.getMyTeam();
      state = AsyncData(fresh);
    } catch (_) {
      // Offline or the request failed — the cached team already on screen
      // stays put.
    }
  }
}

final teamGateProvider = AsyncNotifierProvider<TeamGateNotifier, TeamDetail?>(
  TeamGateNotifier.new,
);

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

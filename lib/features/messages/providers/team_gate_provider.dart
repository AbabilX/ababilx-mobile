import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/first_load_timeout.dart';
import '../../team/data/models/team_models.dart';
import '../../team/data/team_repository.dart';

/// The team gate behind Messages.
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
    // First-ever load, nothing cached yet: this has to wait on the network —
    // but a weak/dead connection must fail into the offline state quickly
    // rather than hang out Dio's full 15s connect + 30s receive timeout.
    return repo.getMyTeam().timeout(firstLoadNetworkTimeout);
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

final teamMembersProvider = Provider<List<TeamMember>>((ref) {
  final team = ref.watch(teamGateProvider);
  return team.maybeWhen(
    data: (d) => d?.members.where((m) => m.status == 'active').toList() ?? [],
    orElse: () => [],
  );
});

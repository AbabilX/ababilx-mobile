import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../profile/providers/profile_provider.dart';
import 'team_gate_provider.dart';

/// The `independent_chat` capability from `GET /api/me`.
final independentChatProvider = Provider<bool>((ref) {
  return ref.watch(profileProvider).valueOrNull?.independentChat ?? false;
});

/// Whether this account can use chat at all.
///
/// Chat stopped being a workspace feature — an accepted personal connection is
/// enough — so a team-less account with independent chat on gets the whole
/// messaging shell. Every boot gate and availability branch reads this instead
/// of [hasTeamProvider]: gating on the team alone is what left a brand-new user
/// on a header-less "join a team on the web" page with no realtime socket
/// behind it and no way to reach the personal surfaces.
final chatEnabledProvider = Provider<bool>((ref) {
  if (ref.watch(hasTeamProvider)) return true;
  return ref.watch(independentChatProvider);
});

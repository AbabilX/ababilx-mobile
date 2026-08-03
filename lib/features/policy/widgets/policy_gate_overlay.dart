import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/profile/providers/profile_provider.dart';
import 'policy_accept_card.dart';

/// Blocks the app behind a full-screen card until the current user has
/// accepted the active policy version. Web-parity gate: without this,
/// a user who signs in on mobile before ever visiting the web app gets
/// stuck — every non-exempt API call 403s with `policy_not_accepted` and
/// screens just render empty.
class PolicyGateOverlay extends ConsumerWidget {
  const PolicyGateOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(profileProvider).valueOrNull;
    if (user == null || user.acceptPolicy) return const SizedBox.shrink();
    return const PolicyAcceptCard();
  }
}

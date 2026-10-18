import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/providers/auth_provider.dart';
import 'live_session.dart';

/// Boots the live history answerer once signed in, so a linked computer's
/// `history.wake` finds something listening (same arrangement as GhostSync).
class HistoryLiveSync extends ConsumerWidget {
  const HistoryLiveSync({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(authProvider).valueOrNull == true) {
      ref.watch(historyLiveProvider);
    }
    return child;
  }
}

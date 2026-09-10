import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/router_path.dart';
import '../group/providers/group_call_provider.dart';
import '../providers/voice_call_provider.dart';
import 'call_lock_screen_guard.dart';

/// The one route that may be seen on a locked phone: the call's own screen.
///
/// The group lobby and every message route stay behind the keyguard. A DM
/// call screen still counts while it says "Call ended", for the moment before
/// `CallStoreSync` leaves it; a group call screen stops counting on Leave.
bool callScreenOnTop({
  required String path,
  required VoiceCallPhase voice,
  required bool groupActive,
}) =>
    (path == '/call' && voice != VoiceCallPhase.idle) ||
    (path == '/group-call' && groupActive);

/// Feeds [CallLockScreenGuard] from the router and both call providers.
class CallLockScreenHost extends ConsumerWidget {
  const CallLockScreenHost({
    super.key,
    required this.router,
    required this.child,
  });

  final GoRouter router;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final voice = ref.watch(
      voiceCallProvider.select((state) => (state.phase, state.active)),
    );
    final groupActive = ref.watch(
      groupCallProvider.select((state) => state.active),
    );
    return ListenableBuilder(
      listenable: router.routerDelegate,
      builder: (context, _) => CallLockScreenGuard(
        callVisible: callScreenOnTop(
          path: currentRoutePath(router),
          voice: voice.$1,
          groupActive: groupActive,
        ),
        callLive: voice.$2 || groupActive,
        child: child,
      ),
    );
  }
}

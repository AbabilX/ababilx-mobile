import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_translations.dart';
import '../../../core/router/router_path.dart';
import '../call_status_text.dart';
import '../group/providers/group_call_provider.dart';
import '../providers/voice_call_provider.dart';
import 'call_return_bar.dart';

/// The bar Signal and WhatsApp show across the top of the app while a call is
/// running and its screen is not on top: who it is with, how it is going, and
/// tap to get back to it.
///
/// The notification in the shade covers the case where the user has left the
/// app entirely. This covers the more common one — they minimised the call and
/// are still inside AbabilX, where a live call was previously invisible and
/// unreachable.
class ActiveCallBanner extends ConsumerWidget {
  const ActiveCallBanner({
    super.key,
    required this.router,
    required this.child,
  });

  final GoRouter router;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dm = ref.watch(voiceCallProvider);
    final lang = ref.watch(appLanguageProvider);
    final group = ref.watch(groupCallProvider);
    final dmActive = dm.active;
    final groupActive = group.phase == GroupCallPhase.connected;

    // The delegate is a ChangeNotifier, so the bar re-evaluates as the user
    // navigates rather than only when call state changes.
    return AnimatedBuilder(
      animation: router.routerDelegate,
      builder: (context, _) {
        final target = dmActive ? '/call' : '/group-call';
        final show =
            (dmActive || groupActive) && currentRoutePath(router) != target;

        // The shape of this subtree NEVER changes, and that is load-bearing.
        // [child] is go_router's `_CustomNavigator`, keyed by a
        // `GlobalObjectKey`. Returning it bare when there is no call and
        // wrapping it in a Column when there is moved a GlobalKey between
        // parents in the same frame the router was rebuilding its match list,
        // which crashed on every hangup: "Duplicate GlobalKey detected in
        // widget tree", then the navigator element deactivated while already
        // failed. An `if (show)` in the children list is the same bug more
        // quietly — it shifts the Expanded from slot 1 to slot 0, and children
        // are matched by index. So the slot is always occupied, by an empty
        // box when there is nothing to say.
        return Column(
          children: [
            // The bar itself takes the status-bar inset (its own SafeArea), so
            // it tints that strip the way WhatsApp does. Without removing the
            // same inset from the screen underneath, both would pay for it and
            // the content would sit a whole status bar too low.
            if (show)
              _bar(
                dm: dm,
                dmActive: dmActive,
                group: group,
                target: target,
                lang: lang,
              )
            else
              const SizedBox.shrink(),
            Expanded(
              child: MediaQuery.removePadding(
                context: context,
                removeTop: show,
                child: child,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _bar({
    required VoiceCallState dm,
    required bool dmActive,
    required GroupCallState group,
    required String target,
    required String lang,
  }) => dmActive
      ? CallReturnBar(
          title: dm.peerName,
          // The same line the call screen and the PiP window show, so the
          // three can never disagree about what the call is doing.
          status: () => voiceCallStatusText(dm, lang: lang),
          ticking: dm.phase == VoiceCallPhase.connected,
          alerting: dm.reconnecting,
          onTap: () => router.go(target),
        )
      : CallReturnBar(
          title: group.title,
          // No duration: the room's start time is when *someone* began the
          // call, not when this device joined, and a timer that is wrong is
          // worse than a count that is right.
          status: () => _groupStatus(group),
          onTap: () => router.go(target),
        );

  static String _groupStatus(GroupCallState group) {
    final count = group.participants.length;
    return count <= 1 ? 'In call' : '$count in call';
  }
}

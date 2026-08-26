import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../group/providers/group_call_provider.dart';
import '../providers/voice_call_provider.dart';

/// The bar Signal shows across the top of the app while a call is running and
/// its screen is not on top: tap it to get back to the call.
///
/// The notification in the shade covers the case where the user has left the
/// app entirely. This covers the more common one — they pressed back and are
/// still inside AbabilX, where a live call was previously invisible and
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
    final dmActive = ref.watch(voiceCallProvider).active;
    final groupActive =
        ref.watch(groupCallProvider).phase == GroupCallPhase.connected;
    if (!dmActive && !groupActive) return child;

    // The delegate is a ChangeNotifier, so the bar re-evaluates as the user
    // navigates rather than only when call state changes.
    return AnimatedBuilder(
      animation: router.routerDelegate,
      builder: (context, _) {
        final path = router.routerDelegate.currentConfiguration.uri.path;
        final target = dmActive ? '/call' : '/group-call';
        if (path == target) return child;
        return Column(
          children: [
            _Bar(
              label: dmActive
                  ? 'Tap to return to call'
                  : 'Tap to return to group call',
              onTap: () => router.go(target),
            ),
            Expanded(child: child),
          ],
        );
      },
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Material(
      color: colors.primary,
      child: SafeArea(
        bottom: false,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: 34,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.phone_in_talk_rounded,
                  size: 15,
                  color: colors.onPrimary,
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: textTheme.labelLarge?.copyWith(
                    color: colors.onPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

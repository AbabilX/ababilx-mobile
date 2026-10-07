import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/router/app_router.dart';
import 'providers/group_call_provider.dart';
import 'widgets/group_call_invite_dialog.dart';
import '../../../shared/widgets/app_toast.dart';

/// Renders the ringing group-call invite above whatever screen is showing, and
/// surfaces join/screen-share failures as a toast at the top.
///
/// Lives inside `MaterialApp.builder` so it has a Theme and a Directionality —
/// a ringing invite can arrive on any route.
class GroupCallInviteHost extends ConsumerWidget {
  const GroupCallInviteHost({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invite = ref.watch(groupCallProvider.select((s) => s.invite));

    ref.listen(groupCallProvider.select((s) => s.error), (_, error) {
      if (error == null || error.isEmpty) return;
      // This widget sits above the Navigator, so its own context finds no
      // overlay; the root navigator's is the one every route draws under.
      showAppToastIn(
        rootNavigatorKey.currentState?.overlay,
        error,
        isError: true,
      );
      ref.read(groupCallProvider.notifier).clearError();
    });

    return Stack(
      children: [
        child,
        if (invite != null)
          Positioned.fill(child: GroupCallInviteDialog(call: invite)),
      ],
    );
  }
}

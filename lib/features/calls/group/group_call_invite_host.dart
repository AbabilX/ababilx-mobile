import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers/group_call_provider.dart';
import 'widgets/group_call_invite_dialog.dart';

/// Renders the ringing group-call invite above whatever screen is showing, and
/// surfaces join/screen-share failures as a snack bar.
///
/// Lives inside `MaterialApp.builder` so it has a Theme, a Directionality and a
/// ScaffoldMessenger — a ringing invite can arrive on any route.
class GroupCallInviteHost extends ConsumerWidget {
  const GroupCallInviteHost({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invite = ref.watch(groupCallProvider.select((s) => s.invite));

    ref.listen(groupCallProvider.select((s) => s.error), (_, error) {
      if (error == null || error.isEmpty) return;
      final messenger = ScaffoldMessenger.maybeOf(context);
      messenger?.showSnackBar(SnackBar(content: Text(error)));
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

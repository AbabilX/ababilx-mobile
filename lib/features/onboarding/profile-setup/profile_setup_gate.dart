import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../messages/add-friends/add_friends_pending.dart';
import '../../profile/providers/profile_provider.dart';
import 'profile_setup_flow.dart';
import 'profile_setup_store.dart';

/// Puts name, username and picture in front of [child] for a new
/// account — after the recovery screen, where the reference app puts its own
/// profile step. Decided once per account; once shown it stays until finished,
/// even if the server's new-account window closes while the person is typing.
class ProfileSetupGate extends ConsumerStatefulWidget {
  const ProfileSetupGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<ProfileSetupGate> createState() => _ProfileSetupGateState();
}

class _ProfileSetupGateState extends ConsumerState<ProfileSetupGate> {
  String? _userId;

  /// Null while the stored answer is being read.
  bool? _show;

  Future<void> _decide(String userId, bool isNewAccount) async {
    final stored = await ProfileSetupStore.read(userId);
    final due = profileSetupDue(isNewAccount: isNewAccount, stored: stored);
    if (due && stored == null) {
      await ProfileSetupStore.write(userId, ProfileSetupStore.pending);
    }
    if (mounted && _userId == userId) setState(() => _show = due);
  }

  Future<void> _finish() async {
    setState(() => _show = false);
    // The chat list opens Add friends (link, code, camera) once.
    ref.read(addFriendsAfterOnboardingProvider.notifier).state = true;
    final userId = _userId;
    if (userId != null) {
      await ProfileSetupStore.write(userId, ProfileSetupStore.done);
    }
  }

  @override
  Widget build(BuildContext context) {
    final (id, isNew) = ref.watch(
      profileProvider.select(
        (p) => (p.valueOrNull?.id, p.valueOrNull?.isNewAccount ?? false),
      ),
    );
    // No profile (offline cold start) never blocks the app.
    if (id == null || id.isEmpty) return widget.child;
    if (id != _userId) {
      _userId = id;
      _show = null;
      _decide(id, isNew);
    }
    return switch (_show) {
      true => ProfileSetupFlow(onDone: _finish),
      false => widget.child,
      // Blank only for a new account, so nobody else loses a frame to this.
      null => isNew ? const Scaffold() : widget.child,
    };
  }
}

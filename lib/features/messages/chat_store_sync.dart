import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/providers/auth_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/team_gate_provider.dart';

/// Bootstraps chat sidebar + WS when user has a team.
class ChatStoreSync extends ConsumerStatefulWidget {
  const ChatStoreSync({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<ChatStoreSync> createState() => _ChatStoreSyncState();
}

class _ChatStoreSyncState extends ConsumerState<ChatStoreSync> {
  bool _booted = false;

  @override
  Widget build(BuildContext context) {
    final isLoggedIn = ref.watch(authProvider).valueOrNull ?? false;
    final hasTeam = ref.watch(hasTeamProvider);

    if (isLoggedIn && hasTeam && !_booted) {
      _booted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(chatProvider.notifier).ensureReady();
      });
    }

    if (!isLoggedIn || !hasTeam) {
      _booted = false;
    }

    ref.listen(hasTeamProvider, (prev, next) {
      if (next && prev != next) {
        ref.read(chatProvider.notifier).ensureReady();
      }
    });

    return widget.child;
  }
}

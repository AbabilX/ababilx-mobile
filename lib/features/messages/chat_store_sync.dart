import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/providers/auth_provider.dart';
import 'providers/chat_access_provider.dart';
import 'providers/chat_provider.dart';

/// Bootstraps the chat sidebar + WS for any account that can chat at all.
///
/// Not "has a team": a team-less account with independent chat on still needs
/// the socket, or its personal DMs arrive only on a manual refresh.
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
    final canChat = ref.watch(chatEnabledProvider);

    if (isLoggedIn && canChat && !_booted) {
      _booted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(chatProvider.notifier).ensureReady();
      });
    }

    if (!isLoggedIn || !canChat) {
      _booted = false;
    }

    ref.listen(chatEnabledProvider, (prev, next) {
      if (next && prev != next) {
        ref.read(chatProvider.notifier).ensureReady();
      }
    });

    return widget.child;
  }
}

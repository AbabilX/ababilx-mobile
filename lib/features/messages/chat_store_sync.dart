import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/providers/auth_provider.dart';
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

class _ChatStoreSyncState extends ConsumerState<ChatStoreSync>
    with WidgetsBindingObserver {
  bool _booted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Coming back to the app is a catch-up, not just a reconnect.
  ///
  /// `WsLinkWatch` revives the socket; this re-reads what a gap in it hid. Both
  /// are needed: a socket that reconnects has a gap by definition, and one that
  /// looked healthy the whole time may still have been written to while the
  /// process was frozen. The reference app does the same pair on foreground —
  /// connect, then fetch.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    // No-ops before bootstrap, so a resume during launch cannot race it.
    ref.read(chatProvider.notifier).resyncNow();
  }

  @override
  Widget build(BuildContext context) {
    final isLoggedIn = ref.watch(authProvider).valueOrNull ?? false;
    if (isLoggedIn && !_booted) {
      _booted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(chatProvider.notifier).ensureReady();
      });
    }

    if (!isLoggedIn) {
      _booted = false;
    }

    return widget.child;
  }
}

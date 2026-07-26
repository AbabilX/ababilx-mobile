import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/providers/auth_provider.dart';
import '../messages/providers/team_gate_provider.dart';
import 'providers/voice_call_provider.dart';

class CallStoreSync extends ConsumerStatefulWidget {
  const CallStoreSync({super.key, required this.router, required this.child});

  final GoRouter router;
  final Widget child;

  @override
  ConsumerState<CallStoreSync> createState() => _CallStoreSyncState();
}

class _CallStoreSyncState extends ConsumerState<CallStoreSync> {
  bool _booted = false;
  bool _shutdownScheduled = false;

  String get _currentPath =>
      widget.router.routerDelegate.currentConfiguration.uri.path;

  @override
  Widget build(BuildContext context) {
    final loggedIn = ref.watch(authProvider).valueOrNull ?? false;
    final hasTeam = ref.watch(hasTeamProvider);

    if (loggedIn && hasTeam && !_booted) {
      _booted = true;
      _shutdownScheduled = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(voiceCallProvider.notifier).bootstrap();
      });
    }
    if ((!loggedIn || !hasTeam) && _booted && !_shutdownScheduled) {
      _booted = false;
      _shutdownScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        await ref.read(voiceCallProvider.notifier).shutdown();
        if (!mounted) return;
        _shutdownScheduled = false;
      });
    }

    ref.listen(voiceCallProvider, (previous, next) {
      if (next.shouldOpenCallScreen && _currentPath != '/call') {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          widget.router.go('/call');
        });
        return;
      }
      if (next.phase == VoiceCallPhase.idle && _currentPath == '/call') {
        final conversationId = previous?.conversationId;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (conversationId != null && conversationId.isNotEmpty) {
            widget.router.go('/messages/$conversationId');
          } else {
            widget.router.go('/messages');
          }
        });
      }
    });

    return widget.child;
  }
}

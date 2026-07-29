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

class _CallStoreSyncState extends ConsumerState<CallStoreSync>
    with WidgetsBindingObserver {
  bool _booted = false;
  bool _shutdownScheduled = false;
  AppLifecycleState _lifecycle = AppLifecycleState.resumed;

  String get _currentPath =>
      widget.router.routerDelegate.currentConfiguration.uri.path;

  bool get _isForeground => _lifecycle == AppLifecycleState.resumed;

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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycle = state;
    // CallKit may accept while backgrounded; open /call once Flutter is active.
    if (state == AppLifecycleState.resumed) {
      _openCallScreenIfNeeded(ref.read(voiceCallProvider));
    }
  }

  void _openCallScreenIfNeeded(VoiceCallState next) {
    if (!next.shouldOpenCallScreen || _currentPath == '/call') return;
    // Never push Flutter navigation over native CallKit / locked / background UI.
    if (!_isForeground) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_isForeground) return;
      if (_currentPath == '/call') return;
      if (!ref.read(voiceCallProvider).shouldOpenCallScreen) return;
      widget.router.go('/call');
    });
  }

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
      if (next.shouldOpenCallScreen) {
        _openCallScreenIfNeeded(next);
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

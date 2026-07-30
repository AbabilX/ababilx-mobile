import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/providers/auth_provider.dart';
import '../messages/providers/team_gate_provider.dart';
import '../profile/providers/user_status_provider.dart';
import 'providers/in_call_presence_provider.dart';
import 'providers/voice_call_provider.dart';
import 'voice_call_log.dart';

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

  /// Flutter route/UI can update while resumed or in the brief inactive
  /// transition (e.g. notification shade). Paused/hidden → native CallKit.
  bool get _canOpenFlutterCallScreen =>
      _lifecycle == AppLifecycleState.resumed ||
      _lifecycle == AppLifecycleState.inactive;

  bool get _isBackgrounded =>
      _lifecycle == AppLifecycleState.paused ||
      _lifecycle == AppLifecycleState.hidden ||
      _lifecycle == AppLifecycleState.detached;

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
    final previous = _lifecycle;
    _lifecycle = state;
    voiceCallLog(
      'lifecycle',
      phase: ref.read(voiceCallProvider).phase.name,
      reason: '${previous.name}→${state.name}',
    );

    if (_canOpenFlutterCallScreen) {
      // CallKit may already be ringing while Flutter was backgrounded — sync
      // state, then open /call (or continue after Accept).
      final notifier = ref.read(voiceCallProvider.notifier);
      unawaited(
        notifier.syncFromNativeIncoming().then((_) {
          if (!mounted) return;
          _openCallScreenIfNeeded(ref.read(voiceCallProvider));
        }),
      );
      return;
    }

    if (_isBackgrounded) {
      // App lost focus while ringing → surface native full-screen CallKit.
      final call = ref.read(voiceCallProvider);
      if (call.phase == VoiceCallPhase.incomingRinging) {
        ref.read(voiceCallProvider.notifier).ensureNativeIncomingUi();
      }
    }
  }

  void _openCallScreenIfNeeded(VoiceCallState next) {
    if (!next.shouldOpenCallScreen || _currentPath == '/call') return;
    if (!_canOpenFlutterCallScreen) {
      // Still prepare the route so Accept / resume lands on /call immediately.
      if (next.phase == VoiceCallPhase.incomingRinging ||
          next.phase == VoiceCallPhase.connecting ||
          next.phase == VoiceCallPhase.connected) {
        voiceCallLog(
          'nav.call.deferred',
          callId: next.call?.id,
          phase: next.phase.name,
          reason: 'lifecycle=${_lifecycle.name}',
        );
      }
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_canOpenFlutterCallScreen) return;
      if (_currentPath == '/call') return;
      if (!ref.read(voiceCallProvider).shouldOpenCallScreen) return;
      voiceCallLog(
        'nav.call.open',
        callId: next.call?.id,
        phase: next.phase.name,
        source: 'CallStoreSync',
      );
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
        unawaited(ref.read(inCallPresenceProvider.notifier).bootstrap());
        unawaited(ref.read(userStatusProvider.notifier).bootstrap());
      });
    }
    if ((!loggedIn || !hasTeam) && _booted && !_shutdownScheduled) {
      _booted = false;
      _shutdownScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        await ref.read(voiceCallProvider.notifier).shutdown();
        ref.read(inCallPresenceProvider.notifier).clear();
        ref.read(userStatusProvider.notifier).clear();
        if (!mounted) return;
        _shutdownScheduled = false;
      });
    }

    ref.listen(voiceCallProvider, (previous, next) {
      if (next.shouldOpenCallScreen) {
        if (_canOpenFlutterCallScreen) {
          _openCallScreenIfNeeded(next);
        } else if (next.phase == VoiceCallPhase.incomingRinging) {
          // Callee app backgrounded / no focus → native CallKit call screen.
          ref.read(voiceCallProvider.notifier).ensureNativeIncomingUi();
        }
        return;
      }
      // Leave /call when idle (normal) or shortly after ended/failed so Decline
      // does not strand the user on a "Done" button for 5s.
      final terminal = next.phase == VoiceCallPhase.ended ||
          next.phase == VoiceCallPhase.failed;
      final wasLive = previous?.shouldOpenCallScreen == true;
      final shouldLeave = _currentPath == '/call' &&
          (next.phase == VoiceCallPhase.idle || terminal) &&
          (wasLive ||
              previous?.phase == VoiceCallPhase.ended ||
              previous?.phase == VoiceCallPhase.failed);
      if (!shouldLeave) return;
      final conversationId = next.conversationId ?? previous?.conversationId;
      final delay = terminal
          ? const Duration(milliseconds: 700)
          : Duration.zero;
      Future<void>.delayed(delay, () {
        if (!mounted || _currentPath != '/call') return;
        final phase = ref.read(voiceCallProvider).phase;
        if (phase != VoiceCallPhase.idle &&
            phase != VoiceCallPhase.ended &&
            phase != VoiceCallPhase.failed) {
          return;
        }
        if (conversationId != null && conversationId.isNotEmpty) {
          widget.router.go('/messages/$conversationId');
        } else {
          widget.router.go('/messages');
        }
      });
    });

    return widget.child;
  }
}

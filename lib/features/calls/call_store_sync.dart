import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/router_path.dart';
import '../auth/providers/auth_provider.dart';
import '../chat-lock/data/chat_lock_index.dart';
import '../profile/providers/user_status_provider.dart';
import 'call_exit_route.dart';
import 'call_trace.dart';
import 'providers/in_call_presence_provider.dart';
import 'providers/voice_call_provider.dart';
import 'voice_call_log.dart';
import '../presence/online_presence_provider.dart';

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

  /// True once this call has occupied `/call`. Leaving that route while the
  /// call remains live is a presentation choice (minimise, share, deep link),
  /// not permission for lifecycle resume to expand it again.
  bool _callScreenWasPresented = false;

  /// The call whose ending already scheduled the way out of /call.
  String _leftCallId = '';

  String get _currentPath => currentRoutePath(widget.router);

  /// Flutter route/UI can update while resumed or in the brief inactive
  /// transition (e.g. notification shade). Paused/hidden → native CallKit.
  /// Same rule the call providers use — see `flutterOwnsRingingUi`.
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
    _callScreenWasPresented = _currentPath == '/call';
    widget.router.routerDelegate.addListener(_onRouteChanged);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    widget.router.routerDelegate.removeListener(_onRouteChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _onRouteChanged() {
    final path = _currentPath;
    if (path == '/call' && ref.read(voiceCallProvider).active) {
      _callScreenWasPresented = true;
    }
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
    unawaited(ref.read(voiceCallProvider.notifier).onAppLifecycle(state));

    if (_canOpenFlutterCallScreen) {
      // CallKit may already be ringing while Flutter was backgrounded — sync
      // state, then open /call (or continue after Accept).
      final notifier = ref.read(voiceCallProvider.notifier);
      unawaited(
        notifier.syncFromNativeIncoming().then((_) async {
          if (!mounted) return;
          // Flutter owns the ringing UI again — this clears any CallKit screen
          // a push raised while we were backgrounded.
          await notifier.ensureNativeIncomingUi();
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
    if (!next.shouldOpenCallScreen) return;
    if (_currentPath == '/call') {
      _callScreenWasPresented = true;
      return;
    }
    if (_callScreenWasPresented) return;
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
      _callScreenWasPresented = true;
      widget.router.go('/call');
    });
  }

  @override
  Widget build(BuildContext context) {
    final loggedIn = ref.watch(authProvider).valueOrNull ?? false;
    // Every signed-in account can chat, with a workspace or without one, so
    // every signed-in phone has to be able to ring.
    if (loggedIn && !_booted) {
      _booted = true;
      _shutdownScheduled = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(voiceCallProvider.notifier).bootstrap();
        unawaited(ref.read(inCallPresenceProvider.notifier).bootstrap());
        unawaited(ref.read(userStatusProvider.notifier).bootstrap());
        unawaited(ref.read(onlinePresenceProvider.notifier).bootstrap());
      });
    }
    if (!loggedIn && _booted && !_shutdownScheduled) {
      _booted = false;
      _shutdownScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        await ref.read(voiceCallProvider.notifier).shutdown();
        ref.read(inCallPresenceProvider.notifier).clear();
        ref.read(userStatusProvider.notifier).clear();
        ref.read(onlinePresenceProvider.notifier).shutdown();
        if (!mounted) return;
        _shutdownScheduled = false;
      });
    }

    ref.listen(voiceCallProvider, (previous, next) {
      if (next.shouldOpenCallScreen) {
        if (previous?.shouldOpenCallScreen != true) {
          _callScreenWasPresented = false;
        }
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
      final terminal =
          next.phase == VoiceCallPhase.ended ||
          next.phase == VoiceCallPhase.failed;
      final wasLive = previous?.shouldOpenCallScreen == true;
      final shouldLeave =
          _currentPath == '/call' &&
          (next.phase == VoiceCallPhase.idle || terminal) &&
          (wasLive ||
              previous?.phase == VoiceCallPhase.ended ||
              previous?.phase == VoiceCallPhase.failed);
      if (!next.shouldOpenCallScreen) _callScreenWasPresented = false;
      if (!shouldLeave) return;
      final conversationId = next.conversationId ?? previous?.conversationId;
      // The only owner of leaving /call, and once per call: `ended` and the
      // `idle` after it both ask, and a second navigation while the first
      // route is still animating in is how the chat list came to be built
      // twice. A brief beat on a terminal phase so "Busy" / "Call ended" can
      // be read; a failure gets a little longer.
      final leaving = next.call?.id ?? previous?.call?.id ?? '';
      if (leaving.isNotEmpty && leaving == _leftCallId) return;
      _leftCallId = leaving;
      final delay = next.phase == VoiceCallPhase.failed
          ? const Duration(milliseconds: 900)
          : terminal
          ? const Duration(milliseconds: 650)
          : Duration.zero;
      Future<void>.delayed(delay, () {
        if (!mounted || _currentPath != '/call') return;
        final phase = ref.read(voiceCallProvider).phase;
        if (phase != VoiceCallPhase.idle &&
            phase != VoiceCallPhase.ended &&
            phase != VoiceCallPhase.failed) {
          return;
        }
        callTrace(
          'ROUTE_AWAY_FROM_CALL',
          callId: next.call?.id ?? previous?.call?.id,
          previousPhase: previous?.phase.name,
          newPhase: phase.name,
          source: 'CallStoreSync',
        );
        widget.router.go(callExitRoute(conversationId, ChatLockIndex.cached));
      });
    });

    return widget.child;
  }
}

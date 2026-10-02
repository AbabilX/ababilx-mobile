import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/providers/auth_provider.dart';
import '../calls/group/providers/group_call_provider.dart';
import '../calls/providers/voice_call_provider.dart';
import '../messages/message_e2ee/message_entry_ready.dart';
import '../onboarding/permissions/permission_intro.dart';
import 'fcm_log.dart';
import 'full_screen_intent_prompt.dart';
import 'providers/fcm_provider.dart';

/// Starts FCM after login / cold start; attaches GoRouter for deep links.
class FcmBootstrap extends ConsumerStatefulWidget {
  const FcmBootstrap({super.key, required this.router, required this.child});

  final GoRouter router;
  final Widget child;

  @override
  ConsumerState<FcmBootstrap> createState() => _FcmBootstrapState();
}

class _FcmBootstrapState extends ConsumerState<FcmBootstrap>
    with WidgetsBindingObserver {
  StreamSubscription<List<ConnectivityResult>>? _networkSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _networkSub = Connectivity().onConnectivityChanged.listen((results) {
      if (results.any((result) => result != ConnectivityResult.none)) {
        _retryRegistration();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _retryRegistration();
  }

  void _retryRegistration() {
    if (!(ref.read(authProvider).valueOrNull ?? false)) return;
    unawaited(ref.read(fcmServiceProvider).retryPendingRegistration());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_networkSub?.cancel());
    super.dispose();
  }

  bool _startedForSession = false;

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final isLoggedIn = auth.valueOrNull ?? false;
    final isLoading = auth.isLoading;

    final fcm = ref.read(fcmServiceProvider);
    fcm.router = widget.router;
    fcm.flushPendingNav();

    ref.listen(authProvider, (prev, next) {
      final wasIn = prev?.valueOrNull ?? false;
      final nowIn = next.valueOrNull ?? false;
      if (!wasIn && nowIn) {
        fcmLog('bootstrap.auth.login → start FCM');
        _startForSession();
      }
      if (wasIn && !nowIn) {
        fcmLog('bootstrap.auth.logout');
        _startedForSession = false;
      }
      if (nowIn && !next.isLoading) {
        ref.read(fcmServiceProvider).flushPendingNav();
      }
    });

    // A launch that skips the message check (this phone holds its key) never
    // shows the permissions screen, so nothing else would settle it.
    if (ref.watch(messageEntryReadyProvider)) {
      PermissionIntro.settle(shown: false);
    }

    if (isLoggedIn && !isLoading && !_startedForSession) {
      fcmLog('bootstrap.cold_start → start FCM');
      _startForSession();
    }

    return widget.child;
  }

  void _startForSession() {
    // build() and the auth listener can observe the same login transition.
    // Claim it synchronously so Android receives one permission request.
    if (_startedForSession) return;
    _startedForSession = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !(ref.read(authProvider).valueOrNull ?? false)) return;
      _boot();
    });
  }

  Future<void> _boot() async {
    fcmLog('bootstrap.boot.begin');
    final fcm = ref.read(fcmServiceProvider);
    fcm.router = widget.router;
    try {
      // Every signed-in device needs an explicit answer. Deferring the ask for
      // new accounts left them unable to receive visible message and ongoing
      // call notifications during their first session.
      // Not over the "Allow permissions" screen: wait for it, and leave the
      // notification ask to it when it ran (this launch or an earlier one).
      final shownNow = await PermissionIntro.settled;
      if (!mounted || !(ref.read(authProvider).valueOrNull ?? false)) return;
      final ask =
          !shownNow &&
          await PermissionIntro.answer() != PermissionIntro.answeredNext;
      final granted = await fcm.start(askPermission: ask);
      fcmLog('bootstrap.boot.done', 'permissionGranted=$granted');
      if (!mounted) return;
      ref.read(notificationPermissionProvider.notifier).setGranted(granted);
      if (granted) {
        unawaited(
          FullScreenIntentPrompt.maybeAsk(
            callLive: () =>
                mounted &&
                (ref.read(voiceCallProvider).active ||
                    ref.read(groupCallProvider).active),
          ),
        );
      }
    } catch (e, st) {
      fcmLog('bootstrap.boot.fail', '$e\n$st');
      if (!mounted) return;
      ref.read(notificationPermissionProvider.notifier).setGranted(false);
    }
  }
}

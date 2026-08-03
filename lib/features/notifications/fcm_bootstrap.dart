import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/providers/auth_provider.dart';
import 'fcm_log.dart';
import 'providers/fcm_provider.dart';

/// Starts FCM after login / cold start; attaches GoRouter for deep links.
class FcmBootstrap extends ConsumerStatefulWidget {
  const FcmBootstrap({super.key, required this.router, required this.child});

  final GoRouter router;
  final Widget child;

  @override
  ConsumerState<FcmBootstrap> createState() => _FcmBootstrapState();
}

class _FcmBootstrapState extends ConsumerState<FcmBootstrap> {
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
        _boot();
      }
      if (wasIn && !nowIn) {
        fcmLog('bootstrap.auth.logout');
        _startedForSession = false;
      }
      if (nowIn && !next.isLoading) {
        ref.read(fcmServiceProvider).flushPendingNav();
      }
    });

    if (isLoggedIn && !isLoading && !_startedForSession) {
      _startedForSession = true;
      fcmLog('bootstrap.cold_start → start FCM');
      WidgetsBinding.instance.addPostFrameCallback((_) => _boot());
    }

    return widget.child;
  }

  Future<void> _boot() async {
    fcmLog('bootstrap.boot.begin');
    final fcm = ref.read(fcmServiceProvider);
    fcm.router = widget.router;
    try {
      final granted = await fcm.start();
      fcmLog('bootstrap.boot.done', 'permissionGranted=$granted');
      if (!mounted) return;
      ref.read(notificationPermissionProvider.notifier).setGranted(granted);
    } catch (e, st) {
      fcmLog('bootstrap.boot.fail', '$e\n$st');
      if (!mounted) return;
      ref.read(notificationPermissionProvider.notifier).setGranted(false);
    }
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/router/app_router.dart';
import '../../core/router/shell_bottom_bar/shell_chrome_provider.dart';
import '../auth/providers/auth_provider.dart';
import 'data/device_identity_store.dart';
import 'models/device_model.dart';
import 'models/file_dto.dart';
import 'providers/local_share_providers.dart';
import 'widgets/incoming_request_sheet.dart';

/// App-wide Local Share bootstrap.
///
/// Starts the receive server + LAN discovery as soon as the user is signed
/// in (not tied to any particular screen), and shows the accept/decline
/// sheet — on top of whatever screen is current, via [rootNavigatorKey] —
/// whenever a peer requests to send files. This is what lets a device be
/// discoverable/receivable without the Local Share screen being open.
class LocalShareSync extends ConsumerStatefulWidget {
  const LocalShareSync({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<LocalShareSync> createState() => _LocalShareSyncState();
}

class _LocalShareSyncState extends ConsumerState<LocalShareSync>
    with WidgetsBindingObserver {
  bool _booted = false;

  /// Discovery has been started once; before that there is nothing to pause.
  bool _discovering = false;

  /// Discovery is stopped because the app left the screen (see
  /// [NearbyDevicesNotifier.pauseDiscovery]).
  bool _discoveryPaused = false;

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
    if (!_booted || !_discovering) return;
    final nearby = ref.read(nearbyDevicesProvider.notifier);
    switch (state) {
      case AppLifecycleState.resumed:
        if (_discoveryPaused) {
          _discoveryPaused = false;
          // Restarting announces and scans at once, which is also what a
          // Wi-Fi change while backgrounded needs.
          unawaited(nearby.startDiscovery());
        } else {
          nearby.refresh();
        }
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        if (_discoveryPaused) return;
        _discoveryPaused = true;
        unawaited(nearby.pauseDiscovery());
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
  }

  Future<void> _bootstrap() async {
    final fingerprint = await loadOrCreateDeviceFingerprint();
    if (!mounted) return;
    ref.read(deviceFingerprintProvider.notifier).state = fingerprint;

    ref.read(localServerServiceProvider).onReceiveRequested = _handleIncoming;
    await ref.read(localShareSessionsProvider.notifier).startServer();
    if (!mounted) return;
    await ref.read(nearbyDevicesProvider.notifier).startDiscovery();
    if (!mounted) return;
    _discovering = true;
    // The app may have left the screen while the server was starting.
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    if (lifecycle != null && lifecycle != AppLifecycleState.resumed) {
      didChangeAppLifecycleState(lifecycle);
    }
  }

  Future<void> _handleIncoming(
    LocalDevice peer,
    List<LocalFileDto> files,
    Completer<bool> decisionCompleter,
  ) async {
    final ctx = rootNavigatorKey.currentContext;
    if (ctx == null) {
      // No UI to prompt with (e.g. very early app startup) — accept by default.
      decisionCompleter.complete(true);
      return;
    }

    final hiddenNotifier = ref.read(shellBottomBarHiddenProvider.notifier);
    hiddenNotifier.state = true;
    bool accepted = false;
    try {
      accepted = await IncomingRequestSheet.show(ctx, peer: peer, files: files);
    } finally {
      hiddenNotifier.state = false;
    }

    if (!decisionCompleter.isCompleted) decisionCompleter.complete(accepted);
  }

  @override
  Widget build(BuildContext context) {
    final loggedIn = ref.watch(authProvider).valueOrNull ?? false;

    if (loggedIn && !_booted) {
      _booted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(_bootstrap());
      });
    } else if (!loggedIn && _booted) {
      _booted = false;
    }

    return widget.child;
  }
}

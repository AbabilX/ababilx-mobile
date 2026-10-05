import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/localization/app_translations.dart';
import '../../core/router/app_router.dart';
import '../../shared/widgets/app_toast.dart';
import 'engine/protocol/share_peer.dart';
import 'providers/local_share_net.dart';
import 'providers/local_share_providers.dart';
import 'sheets/pair_request_sheet.dart';

/// Keeps Local Share alive for the whole signed-in session.
///
/// Nothing runs for an account that never chose a device name. Once one has,
/// this starts the engine, shows the Accept sheet over whatever screen is up,
/// stops discovery while the app is off screen (the announce every few
/// seconds is exactly the background drain battery managers punish) and
/// rebinds when the Wi-Fi changes.
class LocalShareSync extends ConsumerStatefulWidget {
  const LocalShareSync({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<LocalShareSync> createState() => _LocalShareSyncState();
}

class _LocalShareSyncState extends ConsumerState<LocalShareSync>
    with WidgetsBindingObserver {
  StreamSubscription<List<ConnectivityResult>>? _network;
  bool _paused = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(localSharePairPromptProvider.notifier).state = _askPair;
      ref.read(localShareIncomingProvider.notifier).state = _onIncoming;
    });
    _network = Connectivity().onConnectivityChanged.skip(1).listen((_) {
      if (_paused) return;
      final engine = ref.read(localShareEngineProvider).valueOrNull;
      unawaited(engine?.networkChanged());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_network?.cancel());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final engine = ref.read(localShareEngineProvider).valueOrNull;
    if (engine == null) return;
    switch (state) {
      case AppLifecycleState.resumed:
        if (!_paused) return;
        _paused = false;
        unawaited(LocalShareNet.acquire());
        unawaited(engine.resumeDiscovery());
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        if (_paused) return;
        _paused = true;
        unawaited(engine.pauseDiscovery());
        unawaited(LocalShareNet.release());
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
  }

  /// No screen to ask on means no: a request is never accepted for the user.
  Future<bool> _askPair(SharePeer peer) async {
    final context = rootNavigatorKey.currentContext;
    if (context == null || _paused) return false;
    return showPairRequestSheet(context, peer);
  }

  /// Something arrived while the user is somewhere else in the app: say so
  /// at the top of the screen. Inside Local Share the thread itself shows it.
  void _onIncoming(String deviceId, String messageId) {
    final context = rootNavigatorKey.currentContext;
    if (context == null || _paused) return;
    final path = GoRouter.of(
      context,
    ).routerDelegate.currentConfiguration.uri.path;
    if (path.startsWith('/local-share')) return;
    final peers = ref.read(localSharePeersProvider).valueOrNull ?? const {};
    final name = peers[deviceId]?.name ?? '';
    // The navigator's own overlay: its context sits above that overlay, so
    // looking one up from the context finds nothing.
    showAppToastIn(
      rootNavigatorKey.currentState?.overlay,
      AppTranslations.of(
        ref.read(appLanguageProvider),
        'ls_incoming',
      ).replaceAll('{name}', name).trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Watching is what keeps the engine running while no screen needs it.
    ref.watch(localShareEngineProvider);
    return widget.child;
  }
}

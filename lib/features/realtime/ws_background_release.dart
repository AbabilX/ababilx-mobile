import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/ws_client.dart';
import '../calls/group/providers/group_call_provider.dart';
import '../calls/providers/voice_call_provider.dart';
import '../ghost/providers/ghost_provider.dart';
import 'socket_hold.dart';

/// Lets the realtime socket go once the app has been off screen for
/// [backgroundGrace], unless a live call or Ghost Chat still needs it — see
/// [WsClientBackground.suspend] for why, and [socketHeldInBackground] for the
/// exceptions. Returning to the app reconnects it ([WsLinkWatch] kicks on
/// resume) and the reconnect resyncs chat.
class WsBackgroundRelease extends ConsumerStatefulWidget {
  const WsBackgroundRelease({super.key, required this.child});

  /// Signal's `maxBackgroundTime`: long enough for a quick app switch to come
  /// back to a live socket, short enough that a pocket does not hold one.
  static const backgroundGrace = Duration(minutes: 2);

  final Widget child;

  @override
  ConsumerState<WsBackgroundRelease> createState() =>
      _WsBackgroundReleaseState();
}

class _WsBackgroundReleaseState extends ConsumerState<WsBackgroundRelease>
    with WidgetsBindingObserver {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _timer?.cancel();
        _timer = null;
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        _timer ??= Timer(WsBackgroundRelease.backgroundGrace, _release);
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
  }

  void _release() {
    _timer = null;
    if (!mounted) return;
    if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
      return;
    }
    if (_held()) {
      // Ask again later: the call may end while the app stays in background.
      _timer = Timer(WsBackgroundRelease.backgroundGrace, _release);
      return;
    }
    ref.read(wsClientProvider).suspend();
  }

  bool _held() => socketHeldInBackground(
    voice: ref.read(voiceCallProvider).phase,
    group: ref.read(groupCallProvider).phase,
    ghostInSession: ref.read(ghostProvider).inSession,
  );

  @override
  Widget build(BuildContext context) => widget.child;
}

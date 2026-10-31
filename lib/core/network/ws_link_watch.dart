import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ws_client.dart';
import 'ws_link_decision.dart';

/// Asks the socket whether it is still there, at the two moments it usually is
/// not.
///
/// The connection was opened once at bootstrap and nothing ever checked on it
/// again. A phone that had been asleep, or that walked from Wi-Fi to cellular,
/// came back holding a socket the server had already dropped — and since a dead
/// TCP connection closes nothing on this end, the client went on believing it
/// was live. Chat looked frozen until a manual pull, because HTTP opens its own
/// connection and works.
///
/// The reference app's `IncomingMessageObserver` wakes its connect loop on
/// exactly these: `onAppForegrounded`, and any default-network change through
/// `NetworkConnectionListener` — which disconnects outright when the network
/// goes away, since the socket it had cannot have survived it.
class WsLinkWatch extends ConsumerStatefulWidget {
  const WsLinkWatch({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<WsLinkWatch> createState() => _WsLinkWatchState();
}

class _WsLinkWatchState extends ConsumerState<WsLinkWatch>
    with WidgetsBindingObserver {
  StreamSubscription<List<ConnectivityResult>>? _networkSub;
  List<ConnectivityResult>? _lastResults;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _networkSub = Connectivity().onConnectivityChanged.listen(
      _onNetworkChanged,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_networkSub?.cancel());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    // Cheap on a healthy socket, and the whole fix on a dead one: the keepalive
    // would find it on its own within a minute, and a minute of a chat that
    // does not move is what sent people to pull-to-refresh in the first place.
    unawaited(ref.read(wsClientProvider).kick());
  }

  void _onNetworkChanged(List<ConnectivityResult> results) {
    final action = decideWsLinkAction(_lastResults, results);
    _lastResults = results;
    if (action == WsLinkAction.none) return;
    final ws = ref.read(wsClientProvider);
    // Let go on purpose in the background; a Wi-Fi change must not bring it
    // back. Resuming the app does.
    if (ws.suspended) return;
    // The interface it was opened on is gone either way, so the old socket is
    // scrap. Going offline stops there — there is nothing to connect onto, and
    // the backoff will be waiting when a route comes back.
    ws.dropSocket();
    if (action == WsLinkAction.reconnect) unawaited(ws.kick());
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ws_client.dart';

/// Whether the realtime socket is up right now.
///
/// Starts from [WsClient.connected], not from the next event: presence and
/// calls often connect first, and listening for "reconnected" alone would read
/// as down until the next drop.
class WsLinkUpNotifier extends Notifier<bool> {
  @override
  bool build() {
    final ws = ref.watch(wsClientProvider);
    final up = ws.reconnects.listen((_) => state = true);
    final down = ws.disconnects.listen((_) => state = false);
    ref.onDispose(() {
      unawaited(up.cancel());
      unawaited(down.cancel());
    });
    return ws.connected;
  }
}

final wsLinkUpProvider = NotifierProvider<WsLinkUpNotifier, bool>(
  WsLinkUpNotifier.new,
);

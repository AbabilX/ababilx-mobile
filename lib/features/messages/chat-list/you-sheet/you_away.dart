import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/ws_client.dart';

/// Away = really offline, WhatsApp's way (server switch `appear_offline`,
/// 0186): nobody sees this account online, and it sees nobody online either.
/// Messages and calls still arrive. Off until the server says otherwise.
///
/// Follows `me.appear_offline` from the account's other devices and re-reads
/// the server on every socket reconnect, like the typing switch.
class AwayNotifier extends Notifier<bool> {
  /// Bumped by every local write, so an older read cannot flip it back.
  int _writes = 0;

  @override
  bool build() {
    final ws = ref.read(wsClientProvider);
    final events = ws.events.listen(_onEvent);
    final reconnects = ws.reconnects.listen((_) => unawaited(_load()));
    ref.onDispose(() {
      unawaited(events.cancel());
      unawaited(reconnects.cancel());
    });
    Future.microtask(_load);
    return false;
  }

  void _onEvent(Map<String, dynamic> event) {
    if (event['type'] != 'me.appear_offline') return;
    final on = event['appear_offline'];
    if (on is bool) state = on;
  }

  Future<void> _load() async {
    final stamp = _writes;
    try {
      final res = await ref
          .read(apiClientProvider)
          .get(ApiConstants.meAppearOffline);
      if (stamp != _writes) return;
      state = _enabled(res.data);
    } catch (_) {}
  }

  /// Returns false when the server refused; the switch is put back.
  Future<bool> set(bool on) async {
    final previous = state;
    final stamp = ++_writes;
    state = on;
    try {
      final res = await ref
          .read(apiClientProvider)
          .put(ApiConstants.meAppearOffline, data: {'enabled': on});
      if (stamp == _writes) state = _enabled(res.data);
      return true;
    } catch (_) {
      if (stamp == _writes) state = previous;
      return false;
    }
  }

  static bool _enabled(dynamic body) {
    final data = body is Map ? body['data'] : null;
    return data is Map && data['enabled'] == true;
  }
}

final awayProvider = NotifierProvider<AwayNotifier, bool>(AwayNotifier.new);

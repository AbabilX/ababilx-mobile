import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/ws_client.dart';

/// The account's typing-indicator switch (the reference app's rule: off means
/// this account neither shows others it is typing nor sees them typing). The
/// server enforces both halves; the client only avoids pointless frames.
///
/// Optimistically true until loaded, which is the server default — a failed
/// load must not silently switch the feature off.
///
/// This copy used to be read once per launch, so a switch flipped on another
/// device — or a first load that failed — stayed wrong until the app was
/// restarted. It now follows `me.typing_indicators` (the server tells every
/// device of the account) and re-reads the server whenever the socket
/// reconnects, since events sent while it was down are gone.
class TypingIndicatorsNotifier extends Notifier<bool> {
  /// Bumped by every local write, so a read that started before it cannot
  /// land afterwards and flip the switch back.
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
    return true;
  }

  void _onEvent(Map<String, dynamic> event) {
    if (event['type'] != 'me.typing_indicators') return;
    final enabled = event['typing'];
    if (enabled is bool) state = enabled;
  }

  Future<void> _load() async {
    final stamp = _writes;
    try {
      final res = await ref
          .read(apiClientProvider)
          .get(ApiConstants.meTypingIndicators);
      if (stamp != _writes) return;
      state = _enabled(res.data);
    } catch (_) {}
  }

  /// Returns false when the server refused; the switch is put back.
  Future<bool> set(bool enabled) async {
    final previous = state;
    final stamp = ++_writes;
    state = enabled;
    try {
      final res = await ref
          .read(apiClientProvider)
          .put(ApiConstants.meTypingIndicators, data: {'enabled': enabled});
      if (stamp == _writes) state = _enabled(res.data);
      return true;
    } catch (_) {
      if (stamp == _writes) state = previous;
      return false;
    }
  }

  static bool _enabled(dynamic body) {
    final data = body is Map ? body['data'] : null;
    return data is Map ? data['enabled'] != false : true;
  }
}

final typingIndicatorsProvider =
    NotifierProvider<TypingIndicatorsNotifier, bool>(
      TypingIndicatorsNotifier.new,
    );

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/ws_client.dart';

/// How long one online event counts for. Web and desktop use the same 90 s:
/// the server re-asserts every connected account once a minute
/// (`RefreshConnectedPresence`), so a peer who is still here renews well
/// inside it and one whose phone died without a goodbye goes dark on its own.
const onlinePresenceTtl = Duration(seconds: 90);

/// userId → when the server last said they were online.
///
/// Fed by the same two socket events web's `presence-store.ts` reads —
/// `attendance.presence` (one edge) and `attendance.presence.snapshot` (the
/// whole roster at connect). The server already fanned these out to phones;
/// nothing on the phone was listening, so no DM ever showed a dot or a line.
class OnlinePresenceNotifier extends Notifier<Map<String, DateTime>> {
  StreamSubscription<Map<String, dynamic>>? _events;
  StreamSubscription<void>? _drops;
  Timer? _sweep;
  bool _booted = false;

  @override
  Map<String, DateTime> build() {
    ref.onDispose(_stop);
    return {};
  }

  Future<void> bootstrap() async {
    if (_booted) return;
    _booted = true;
    final ws = ref.read(wsClientProvider);
    _events = ws.events.listen(_onEvent);
    // Our own socket down means we no longer hear anyone leave. Showing the
    // last roster would claim people are here who may be long gone; the
    // reconnect brings a fresh snapshot.
    _drops = ws.disconnects.listen((_) => clear());
    // Entries only ever expire by time, so something has to redraw when one
    // does, or a dot stays lit until an unrelated rebuild.
    _sweep = Timer.periodic(const Duration(seconds: 15), (_) => _expire());
    await ws.connect();
  }

  void clear() {
    if (state.isNotEmpty) state = {};
  }

  void shutdown() {
    _stop();
    clear();
  }

  void _stop() {
    unawaited(_events?.cancel());
    unawaited(_drops?.cancel());
    _sweep?.cancel();
    _events = null;
    _drops = null;
    _sweep = null;
    _booted = false;
  }

  void _expire() {
    final cutoff = DateTime.now().subtract(onlinePresenceTtl);
    if (!state.values.any((at) => at.isBefore(cutoff))) return;
    state = {
      for (final e in state.entries)
        if (!e.value.isBefore(cutoff)) e.key: e.value,
    };
  }

  void _onEvent(Map<String, dynamic> event) {
    final type = event['type'] as String? ?? '';
    if (type == 'attendance.presence.snapshot') {
      final raw = event['online_user_ids'];
      final now = DateTime.now();
      state = {
        if (raw is List)
          for (final id in raw)
            if (id is String && id.isNotEmpty) id: now,
      };
      return;
    }
    if (type != 'attendance.presence') return;
    final payload = event['presence'];
    if (payload is! Map) return;
    final userId = payload['user_id'] as String? ?? '';
    if (userId.isEmpty) return;
    final next = Map<String, DateTime>.from(state);
    if (payload['online'] == true) {
      // The phone's own clock, not the server's `at`: the TTL is measured
      // against this clock, and a phone a few minutes off would otherwise
      // expire every event on arrival.
      next[userId] = DateTime.now();
    } else {
      next.remove(userId);
    }
    state = next;
  }
}

final onlinePresenceProvider =
    NotifierProvider<OnlinePresenceNotifier, Map<String, DateTime>>(
      OnlinePresenceNotifier.new,
    );

final isUserOnlineProvider = Provider.family<bool, String?>((ref, userId) {
  if (userId == null || userId.isEmpty) return false;
  final at = ref.watch(onlinePresenceProvider.select((m) => m[userId]));
  return at != null && DateTime.now().difference(at) < onlinePresenceTtl;
});

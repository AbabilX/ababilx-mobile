import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/ws_client.dart';

/// Team-wide set of user ids currently in a voice call (ringing or accepted).
class InCallPresenceNotifier extends Notifier<Set<String>> {
  StreamSubscription<Map<String, dynamic>>? _sub;
  bool _booted = false;

  @override
  Set<String> build() {
    ref.onDispose(() {
      unawaited(_sub?.cancel());
      _sub = null;
      _booted = false;
    });
    return {};
  }

  Future<void> bootstrap() async {
    if (_booted) return;
    _booted = true;
    final ws = ref.read(wsClientProvider);
    _sub = ws.events.listen(_onEvent);
    await ws.connect();
  }

  bool isInCall(String? userId) {
    if (userId == null || userId.isEmpty) return false;
    return state.contains(userId);
  }

  void clear() => state = {};

  void _onEvent(Map<String, dynamic> event) {
    final type = event['type'] as String? ?? '';
    if (type == 'call.presence.snapshot') {
      final raw = event['in_call_user_ids'];
      if (raw is! List) {
        state = {};
        return;
      }
      state = {
        for (final id in raw)
          if (id is String && id.isNotEmpty) id,
      };
      return;
    }
    if (type != 'call.presence') return;
    final payload = event['call_presence'];
    if (payload is! Map) return;
    final userId = payload['user_id'] as String? ?? '';
    if (userId.isEmpty) return;
    final inCall = payload['in_call'] == true;
    final next = Set<String>.from(state);
    if (inCall) {
      next.add(userId);
    } else {
      next.remove(userId);
    }
    state = next;
  }
}

final inCallPresenceProvider =
    NotifierProvider<InCallPresenceNotifier, Set<String>>(
      InCallPresenceNotifier.new,
    );

final isUserInCallProvider = Provider.family<bool, String?>((ref, userId) {
  if (userId == null || userId.isEmpty) return false;
  return ref.watch(inCallPresenceProvider).contains(userId);
});

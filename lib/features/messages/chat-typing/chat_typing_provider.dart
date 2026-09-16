import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/ws_client.dart';
import '../../settings/typing-indicators/typing_indicators_provider.dart';

/// A typist disappears this long after their last "typing" frame, so a
/// "stopped" frame lost with a dying socket heals on its own.
const typingTtl = Duration(seconds: 5);

class Typist {
  const Typist(this.name, this.at);
  final String name;
  final DateTime at;
}

/// conversation id -> user id -> last frame. Each conversation's map is
/// replaced, never mutated, so a row watching one conversation through
/// `select` rebuilds only when that conversation changes.
class ChatTypingNotifier extends Notifier<Map<String, Map<String, Typist>>> {
  @override
  Map<String, Map<String, Typist>> build() {
    final sub = ref.read(wsClientProvider).events.listen(_onEvent);
    final timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => prune(DateTime.now()),
    );
    ref.onDispose(() {
      unawaited(sub.cancel());
      timer.cancel();
    });
    return const {};
  }

  void _onEvent(Map<String, dynamic> ev) {
    final type = ev['type'];
    final convId = ev['conversation_id'] as String? ?? '';
    if (convId.isEmpty) return;
    if (type == 'chat.typing') {
      if (kDebugMode) {
        debugPrint(
          '[typing] recv conv=$convId from=${ev['from_user_id']} '
          'typing=${ev['typing']} enabled=${ref.read(typingIndicatorsProvider)}',
        );
      }
      if (!ref.read(typingIndicatorsProvider)) return;
      final userId = ev['from_user_id'] as String? ?? '';
      if (userId.isEmpty) return;
      if (ev['typing'] == false) {
        clear(convId, userId);
      } else {
        apply(
          convId,
          userId,
          ev['typing_user_name'] as String? ?? '',
          DateTime.now(),
        );
      }
    } else if (type == 'chat.message.created') {
      // The indicator vanishes the instant the message it announced lands.
      final msg = ev['message'];
      final senderId = msg is Map ? msg['user_id'] as String? ?? '' : '';
      if (senderId.isNotEmpty) clear(convId, senderId);
    }
  }

  void apply(String convId, String userId, String name, DateTime at) {
    state = {
      ...state,
      convId: {...?state[convId], userId: Typist(name, at)},
    };
  }

  void clear(String convId, String userId) {
    final current = state[convId];
    if (current == null || !current.containsKey(userId)) return;
    final next = {...current}..remove(userId);
    final all = {...state};
    if (next.isEmpty) {
      all.remove(convId);
    } else {
      all[convId] = next;
    }
    state = all;
  }

  void prune(DateTime now) {
    var changed = false;
    final next = <String, Map<String, Typist>>{};
    state.forEach((convId, typists) {
      final live = {
        for (final e in typists.entries)
          if (now.difference(e.value.at) < typingTtl) e.key: e.value,
      };
      if (live.length != typists.length) changed = true;
      if (live.isNotEmpty) {
        next[convId] = live.length == typists.length ? typists : live;
      }
    });
    if (changed) state = next;
  }
}

final chatTypingProvider =
    NotifierProvider<ChatTypingNotifier, Map<String, Map<String, Typist>>>(
      ChatTypingNotifier.new,
    );

/// Names typing in one conversation, oldest first.
List<String> typingNamesOf(Map<String, Typist>? typists) {
  if (typists == null || typists.isEmpty) return const [];
  final list = typists.values.toList()..sort((a, b) => a.at.compareTo(b.at));
  return [for (final t in list) t.name];
}

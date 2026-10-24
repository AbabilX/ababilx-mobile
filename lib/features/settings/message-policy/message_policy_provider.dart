import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';

/// Who may start a chat with this account (server migration 0184).
enum MessagePolicy {
  /// Anyone not blocked; a stranger's first message is a message request.
  requests('requests'),

  /// A stranger must send a connection request and have it accepted first.
  connections('connections');

  const MessagePolicy(this.wire);
  final String wire;

  static MessagePolicy fromWire(Object? value) =>
      value == 'connections' ? connections : requests;
}

/// The account's own setting. Starts at the server default ([requests]) until
/// loaded; the server enforces it on every send, so this copy only draws the
/// Settings row.
class MessagePolicyNotifier extends Notifier<MessagePolicy> {
  /// Bumped by every local write, so an older read cannot undo it.
  int _writes = 0;

  @override
  MessagePolicy build() {
    Future.microtask(_load);
    return MessagePolicy.requests;
  }

  Future<void> _load() async {
    final stamp = _writes;
    try {
      final res = await ref
          .read(apiClientProvider)
          .get(ApiConstants.meMessagePolicy);
      if (stamp == _writes) state = _parse(res.data);
    } catch (_) {}
  }

  /// Returns false when the server refused; the previous value is put back.
  Future<bool> set(MessagePolicy policy) async {
    final previous = state;
    final stamp = ++_writes;
    state = policy;
    try {
      final res = await ref
          .read(apiClientProvider)
          .put(ApiConstants.meMessagePolicy, data: {'policy': policy.wire});
      if (stamp == _writes) state = _parse(res.data);
      return true;
    } catch (_) {
      if (stamp == _writes) state = previous;
      return false;
    }
  }

  static MessagePolicy _parse(dynamic body) {
    final data = body is Map ? body['data'] : null;
    return MessagePolicy.fromWire(data is Map ? data['policy'] : null);
  }
}

final messagePolicyProvider =
    NotifierProvider<MessagePolicyNotifier, MessagePolicy>(
      MessagePolicyNotifier.new,
    );

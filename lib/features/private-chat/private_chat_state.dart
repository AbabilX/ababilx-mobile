import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../messages/providers/chat_provider.dart';
import 'private_chat_api.dart';

/// One DM's private chat switch (server 0160). Either member sets it and it
/// binds both; [by] is who switched it on.
class PrivateChatState {
  const PrivateChatState({required this.enabled, this.by = ''});

  static const off = PrivateChatState(enabled: false);

  final bool enabled;
  final String by;
}

/// Anything newer than the last sidebar fetch, keyed by conversation id:
/// this device's own change, or `chat.private_chat` from the server.
class PrivateChatOverrides extends Notifier<Map<String, PrivateChatState>> {
  @override
  Map<String, PrivateChatState> build() => const {};

  void onEvent(Map<String, dynamic> ev) {
    final id = ev['conversation_id'] as String? ?? '';
    final payload = ev['private_chat'];
    if (id.isEmpty || payload is! Map) return;
    final enabled = payload['enabled'];
    if (enabled is! bool) return;
    state = {
      ...state,
      id: PrivateChatState(
        enabled: enabled,
        by: payload['by'] as String? ?? '',
      ),
    };
  }

  /// Optimistic, and put back if the server refuses — a switch that flips and
  /// silently does nothing reads as working, and here it would read as a
  /// promise about deletion the server never made.
  Future<void> set(String conversationId, bool enabled, String myUserId) async {
    final before = ref.read(conversationPrivateChatProvider(conversationId));
    state = {
      ...state,
      conversationId: PrivateChatState(
        enabled: enabled,
        by: enabled ? myUserId : '',
      ),
    };
    try {
      final (on, by) = await ref
          .read(privateChatApiProvider)
          .setEnabled(conversationId, enabled);
      state = {...state, conversationId: PrivateChatState(enabled: on, by: by)};
    } catch (_) {
      state = {...state, conversationId: before};
      rethrow;
    }
  }
}

final privateChatOverridesProvider =
    NotifierProvider<PrivateChatOverrides, Map<String, PrivateChatState>>(
      PrivateChatOverrides.new,
    );

/// A DM's private chat switch: the live override, else its sidebar row.
/// Always off for a group, a feed and Note to Self.
final conversationPrivateChatProvider =
    Provider.family<PrivateChatState, String>((ref, conversationId) {
      final live = ref.watch(
        privateChatOverridesProvider.select((m) => m[conversationId]),
      );
      if (live != null) return live;
      final conv = ref.watch(
        chatProvider.select((s) => s.conversationById(conversationId)),
      );
      if (conv == null || !conv.hasDmPeer) return PrivateChatState.off;
      return PrivateChatState(
        enabled: conv.privateChat,
        by: conv.privateChatBy,
      );
    });

/// Whether private chat is on in this conversation right now.
final isPrivateChatProvider = Provider.family<bool, String>(
  (ref, conversationId) =>
      ref.watch(conversationPrivateChatProvider(conversationId)).enabled,
);

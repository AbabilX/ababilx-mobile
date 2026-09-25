import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../messages/data/chat_endpoints.dart';
import '../../messages/providers/chat_provider.dart';
import '../../privacy-mode/peer_privacy_provider.dart';

/// One DM's tick switch (server 0159). [hidden] is the DM's state — some
/// member switched ticks off, so neither side sees any; [mine] is this
/// account's own switch.
class ReceiptsHidden {
  const ReceiptsHidden({required this.hidden, required this.mine});

  static const none = ReceiptsHidden(hidden: false, mine: false);

  final bool hidden;
  final bool mine;

  /// The peer holds the switch when the DM is dark and this account is not
  /// the reason — turning ours off then leaves it dark.
  bool get peerHolds => hidden && !mine;
}

/// Anything newer than the last sidebar fetch, keyed by conversation id:
/// this device's own change, or `chat.receipts_hidden` from the server.
class ReceiptsHiddenOverrides extends Notifier<Map<String, ReceiptsHidden>> {
  @override
  Map<String, ReceiptsHidden> build() => const {};

  void onEvent(Map<String, dynamic> ev) {
    final id = ev['conversation_id'] as String? ?? '';
    final payload = ev['receipts_hidden'];
    if (id.isEmpty || payload is! Map) return;
    final hidden = payload['hidden'];
    final mine = payload['mine'];
    if (hidden is! bool || mine is! bool) return;
    state = {...state, id: ReceiptsHidden(hidden: hidden, mine: mine)};
  }

  /// Switches this account's ticks off or on in one DM. Optimistic, and put
  /// back if the server refuses — a switch that flips and silently does
  /// nothing reads as working.
  Future<void> set(String conversationId, bool hide) async {
    final before = ref.read(receiptsHiddenProvider(conversationId));
    state = {
      ...state,
      conversationId: ReceiptsHidden(
        hidden: hide || before.peerHolds,
        mine: hide,
      ),
    };
    try {
      final res = await ref
          .read(apiClientProvider)
          .put(
            const ChatEndpoints().action(conversationId, 'receipts'),
            data: {'hidden': hide},
          );
      final data = unwrapApiData<Map<String, dynamic>>(res);
      state = {
        ...state,
        conversationId: ReceiptsHidden(
          hidden: data['receipts_hidden'] as bool? ?? hide,
          mine: data['my_receipts_hidden'] as bool? ?? hide,
        ),
      };
    } catch (_) {
      state = {...state, conversationId: before};
      rethrow;
    }
  }
}

final receiptsHiddenOverridesProvider =
    NotifierProvider<ReceiptsHiddenOverrides, Map<String, ReceiptsHidden>>(
      ReceiptsHiddenOverrides.new,
    );

/// A DM's tick switch: the live override, else what its sidebar row said.
/// Always [ReceiptsHidden.none] for a group or Note to Self.
final receiptsHiddenProvider = Provider.family<ReceiptsHidden, String>((
  ref,
  conversationId,
) {
  final live = ref.watch(
    receiptsHiddenOverridesProvider.select((m) => m[conversationId]),
  );
  if (live != null) return live;
  final conv = ref.watch(
    chatProvider.select((s) => s.conversationById(conversationId)),
  );
  if (conv == null || !conv.hasDmPeer) return ReceiptsHidden.none;
  return ReceiptsHidden(
    hidden: conv.receiptsHidden,
    mine: conv.myReceiptsHidden,
  );
});

/// Whether this phone draws no delivery state at all on its own messages in
/// a conversation: the peer is private toward us (0152), or somebody hid
/// ticks in this DM (0159). A failure still shows — that is about this phone.
final conversationTicksHiddenProvider = Provider.family<bool, String>(
  (ref, conversationId) =>
      ref.watch(conversationPeerPrivacyProvider(conversationId)) ||
      ref.watch(receiptsHiddenProvider(conversationId)).hidden,
);

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../messages/providers/chat_provider.dart';
import 'privacy_mode_provider.dart';

/// Live privacy-mode flips of DM peers, from `chat.peer_privacy`, keyed by
/// user id. The sidebar row's `peer_privacy` is the truth as of the last
/// fetch; an entry here is anything newer.
class PeerPrivacyOverrides extends Notifier<Map<String, bool>> {
  @override
  Map<String, bool> build() => const {};

  /// Fed by the chat provider's socket handler. A flip about this account
  /// itself came from another of its devices and moves the own switch.
  void onEvent(Map<String, dynamic> ev, String currentUserId) {
    final from = ev['from_user_id'] as String? ?? '';
    final on = ev['peer_privacy'];
    if (from.isEmpty || on is! bool) return;
    if (from == currentUserId) {
      ref.read(privacyModeProvider.notifier).applyRemote(on);
      return;
    }
    state = {...state, from: on};
  }
}

final peerPrivacyOverridesProvider =
    NotifierProvider<PeerPrivacyOverrides, Map<String, bool>>(
      PeerPrivacyOverrides.new,
    );

/// A live flip for one account, or null when none arrived since the last
/// fetch — callers fall back to what their own row said (sidebar, call).
final livePeerPrivacyProvider = Provider.family<bool?, String>(
  (ref, userId) =>
      ref.watch(peerPrivacyOverridesProvider.select((m) => m[userId])),
);

/// Whether the other side of this DM has privacy mode on. Always false for a
/// group, a feed and Note to Self — privacy mode never reaches past a DM.
final conversationPeerPrivacyProvider = Provider.family<bool, String>((
  ref,
  conversationId,
) {
  final conv = ref.watch(
    chatProvider.select((s) => s.conversationById(conversationId)),
  );
  if (conv == null || !conv.hasDmPeer) return false;
  final peerId = conv.peerUserId;
  final live = peerId == null
      ? null
      : ref.watch(livePeerPrivacyProvider(peerId));
  return live ?? conv.peerPrivacy;
});

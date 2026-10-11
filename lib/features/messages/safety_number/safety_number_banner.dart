import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/chat_provider.dart';
import 'group_key_change_banner.dart';
import 'group_roster_notice.dart';
import 'safety_number_provider.dart';
import 'safety_number_screen.dart';
import 'safety_number_strip.dart';

/// The half of safety numbers that actually protects anyone.
///
/// Nobody compares digits twice, so a server that swapped a key after the first
/// conversation would never be caught by a settings screen alone. This watches
/// the peer's key whenever the conversation opens and says so, in the
/// conversation, when it changes. It renders nothing at all otherwise — which
/// is every conversation, almost always.
class SafetyNumberBanner extends ConsumerWidget {
  const SafetyNumberBanner({super.key, required this.conversationId});

  final String conversationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chat = ref.watch(chatProvider);
    final conversation = chat.conversationById(conversationId);
    // A group has many identities to watch; it gets its own strip.
    if (conversation != null &&
        conversation.isGroup &&
        conversation.isEncrypted) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GroupRosterNotice(conversationId: conversationId),
          GroupKeyChangeBanner(conversationId: conversationId),
        ],
      );
    }
    // hasDmPeer, not isDm: in a note to self the peer is the viewer, so there
    // is no second identity to compare and no substitution to catch.
    final peerUserId =
        conversation?.hasDmPeer == true &&
            conversation?.isAccountDeleted != true
        ? (conversation?.peerUserId ?? '')
        : '';
    if (peerUserId.isEmpty) return const SizedBox.shrink();
    final peerName = conversation!.displayTitle(chat.currentUserId);
    final info = ref.watch(safetyNumberProvider(peerUserId)).valueOrNull;
    if (info == null || !info.changed) return const SizedBox.shrink();

    return SafetyNumberStrip(
      text: 'Your safety number with $peerName changed. Tap to verify.',
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) =>
              SafetyNumberScreen(peerUserId: peerUserId, peerName: peerName),
        ),
      ),
    );
  }
}

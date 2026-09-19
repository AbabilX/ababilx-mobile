import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/chat_provider.dart';
import 'safety_number_provider.dart';
import 'safety_number_screen.dart';

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
    // A group has no single peer identity to pin, so there is nothing to watch.
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

    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.errorContainer,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) =>
                SafetyNumberScreen(peerUserId: peerUserId, peerName: peerName),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Icon(
                Icons.gpp_maybe,
                size: 18,
                color: theme.colorScheme.onErrorContainer,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Your safety number with $peerName changed. Tap to verify.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onErrorContainer,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: 18,
                color: theme.colorScheme.onErrorContainer,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

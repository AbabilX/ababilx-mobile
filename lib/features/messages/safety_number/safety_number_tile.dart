import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../chat_icon.dart';
import '../chat-details/details_tile.dart';
import 'safety_number_provider.dart';
import 'safety_number_screen.dart';

/// The conversation-settings entry point. Always present on a DM, so somebody
/// who wants to verify can find it without knowing it exists; the value line
/// carries the warning when the key has changed under them.
class SafetyNumberTile extends ConsumerWidget {
  const SafetyNumberTile({
    super.key,
    required this.peerUserId,
    required this.peerName,
  });

  final String peerUserId;
  final String peerName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = ref.watch(safetyNumberProvider(peerUserId)).valueOrNull;
    return DetailsTile(
      icon: const ChatIcon(HugeIcons.strokeRoundedShieldKey),
      title: 'Safety number',
      value: info == null
          ? 'Verify this conversation'
          : info.changed
          ? 'Changed — verify again'
          : 'Verify this conversation',
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) =>
              SafetyNumberScreen(peerUserId: peerUserId, peerName: peerName),
        ),
      ),
    );
  }
}

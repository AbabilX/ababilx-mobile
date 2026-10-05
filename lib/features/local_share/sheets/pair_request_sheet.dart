import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../engine/protocol/share_peer.dart';
import '../providers/share_account.dart';
import '../share_text.dart';
import '../widgets/share_device_avatar.dart';

/// Another device wants to send to this one. Accepting is once per device:
/// after it, that device's messages and files arrive without asking.
///
/// Closing the sheet any other way than Accept is a refusal.
Future<bool> showPairRequestSheet(BuildContext context, SharePeer peer) async {
  final accepted = await showModalBottomSheet<bool>(
    context: context,
    isDismissible: false,
    enableDrag: false,
    isScrollControlled: true,
    useRootNavigator: true,
    builder: (_) => _PairRequestSheet(peer: peer),
  );
  return accepted ?? false;
}

class _PairRequestSheet extends ConsumerWidget {
  const _PairRequestSheet({required this.peer});

  final SharePeer peer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final account = ref.watch(shareAccountProvider(peer.userId));
    final who = account == null
        ? lsText(ref, 'ls_pair_unknown')
        : account.mine
        ? lsText(ref, 'ls_your_account')
        : lsText(ref, 'ls_pair_connection', name: account.name);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ShareDeviceAvatar(
              deviceType: peer.deviceType,
              userId: peer.userId,
              size: 72,
            ),
            const SizedBox(height: 14),
            Text(
              peer.name,
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(who, style: TextStyle(color: muted)),
            const SizedBox(height: 14),
            Text(
              lsText(ref, 'ls_pair_body', name: peer.name),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: muted),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(lsText(ref, 'ls_decline')),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: Text(lsText(ref, 'ls_accept')),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

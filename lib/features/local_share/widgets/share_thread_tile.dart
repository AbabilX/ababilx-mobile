import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/share_thread_queries.dart';
import '../providers/share_account.dart';
import '../share_text.dart';
import 'share_device_avatar.dart';
import 'share_thread_preview.dart';

/// One device in the Local Share list: who, the last thing said, and whether
/// they are in range right now.
class ShareThreadTile extends ConsumerWidget {
  const ShareThreadTile({
    super.key,
    required this.thread,
    required this.nearby,
    required this.onTap,
  });

  final ShareThread thread;
  final bool nearby;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final device = thread.device;
    final account = ref.watch(shareAccountProvider(device.userId));
    final last = thread.last;
    final unread = thread.unread > 0;
    return ListTile(
      onTap: onTap,
      leading: ShareDeviceAvatar(
        deviceType: device.deviceType,
        userId: device.userId,
        nearby: nearby,
      ),
      title: Text(
        account == null || account.mine
            ? device.name
            : '${device.name} · ${account.name}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontWeight: unread ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
      subtitle: Text(
        device.blocked
            ? lsText(ref, 'ls_blocked')
            : shareThreadPreview(ref, thread),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: colors.onSurfaceVariant,
          fontWeight: unread ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (last != null)
            Text(
              _when(thread.lastOrderMs),
              style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
            ),
          if (unread) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: colors.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${thread.unread}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colors.onPrimary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _when(int ms) {
    final at = DateTime.fromMillisecondsSinceEpoch(ms);
    final now = DateTime.now();
    final today =
        at.year == now.year && at.month == now.month && at.day == now.day;
    return today ? DateFormat.jm().format(at) : DateFormat.MMMd().format(at);
  }
}

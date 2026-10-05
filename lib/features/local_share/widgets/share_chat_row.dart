import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../messages/chat_icon.dart';
import '../../messages/chat_list_filters.dart';
import '../../messages/chat_unread_badge.dart';
import '../data/share_thread_queries.dart';
import '../providers/local_share_providers.dart';
import '../providers/share_account.dart';
import '../share_text.dart';
import 'share_device_avatar.dart';
import 'share_thread_preview.dart';

/// A device thread drawn as a chat-list row. Same metrics as a conversation
/// row; the Wi-Fi glyph beside the time (folder-transfer already means "nearby" on a conversation row) is what says it is Local Share,
/// and it is tinted only while the device is in range.
class ShareChatRow extends ConsumerWidget {
  const ShareChatRow({
    super.key,
    required this.thread,
    required this.onTap,
    this.onLongPress,
  });

  final ShareThread thread;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final device = thread.device;
    final account = ref.watch(shareAccountProvider(device.userId));
    final nearby =
        ref
            .watch(localSharePeersProvider)
            .valueOrNull
            ?.containsKey(device.deviceId) ??
        false;
    final unread = thread.unread > 0;
    final time = thread.last == null
        ? ''
        : relativeChatTime(
            DateTime.fromMillisecondsSinceEpoch(
              thread.lastOrderMs,
            ).toIso8601String(),
          );
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ShareDeviceAvatar(
              deviceType: device.deviceType,
              userId: device.userId,
              size: 52,
              nearby: nearby,
              shareBadge: true,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          account == null || account.mine
                              ? device.name
                              : '${device.name} · ${account.name}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontSize: 16,
                            fontWeight: unread
                                ? FontWeight.w800
                                : FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Tooltip(
                        message: lsText(ref, 'ls_chat_tag'),
                        child: ChatIcon(
                          HugeIcons.strokeRoundedWifi01,
                          size: 15,
                          color: nearby
                              ? colors.primary
                              : colors.onSurfaceVariant,
                        ),
                      ),
                      if (time.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Text(
                          time,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          shareThreadPreview(ref, thread),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            height: 1.28,
                            color: colors.onSurfaceVariant,
                            fontWeight: unread
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                      ),
                      ChatUnreadBadge(count: thread.unread),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

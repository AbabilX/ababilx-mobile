import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../shared/widgets/app_avatar.dart';
import '../chat_icon.dart';
import '../data/models/chat_models.dart';
import '../providers/chat_provider.dart';

Future<void> showDmActionsSheet(
  BuildContext context,
  WidgetRef ref,
  ChatConversation conversation,
) async {
  final name = conversation.peerUserName ?? 'Direct message';
  final avatar = conversation.peerUserAvatar;
  final colors = Theme.of(context).colorScheme;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        final isMuted = conversation.muted;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top drag indicator bar
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colors.onSurfaceVariant.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Large Avatar
                AppAvatar(
                  size: 72,
                  url: avatar,
                  name: name,
                ),
                const SizedBox(height: 12),

                // User Name
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),

                // Subtitle / Status
                if (conversation.peerLeft)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: colors.errorContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Left conversation',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: colors.onErrorContainer,
                      ),
                    ),
                  )
                else
                  Text(
                    'Direct Message',
                    style: TextStyle(
                      fontSize: 13,
                      color: colors.onSurfaceVariant,
                    ),
                  ),

                const SizedBox(height: 24),
                const Divider(height: 1),
                const SizedBox(height: 8),

                // Mute / Unmute Notifications Tile
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: colors.surfaceContainerHighest,
                      shape: BoxShape.circle,
                    ),
                    child: ChatIcon(
                      isMuted
                          ? HugeIcons.strokeRoundedNotificationOff01
                          : HugeIcons.strokeRoundedNotification01,
                      size: 20,
                      color: colors.onSurface,
                    ),
                  ),
                  title: const Text(
                    'Mute Notifications',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    isMuted
                        ? 'Notifications are muted'
                        : 'Receive alerts for new messages',
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: Switch(
                    value: isMuted,
                    onChanged: (val) async {
                      await ref
                          .read(chatProvider.notifier)
                          .muteConversation(conversation.id, val);
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                  ),
                ),

                if (conversation.peerUserId != null) ...[
                  const SizedBox(height: 4),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: colors.surfaceContainerHighest,
                        shape: BoxShape.circle,
                      ),
                      child: ChatIcon(
                        HugeIcons.strokeRoundedUser,
                        size: 20,
                        color: colors.onSurface,
                      ),
                    ),
                    title: const Text(
                      'User ID',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      _maskUserId(conversation.peerUserId!),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    ),
  );
}

String _maskUserId(String id) {
  final trimmed = id.trim();
  if (trimmed.length <= 6) {
    return '***${trimmed.substring(trimmed.length > 2 ? trimmed.length - 2 : 0)}';
  }
  final start = trimmed.substring(0, 3);
  final end = trimmed.substring(trimmed.length - 3);
  return '$start*********$end';
}

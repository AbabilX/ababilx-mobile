import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../shared/widgets/app_avatar.dart';
import '../chat_icon.dart';
import '../data/models/chat_connection.dart';

/// Accepted connection: name block on top, flat action buttons on the bottom row.
class ConnectionRow extends StatelessWidget {
  const ConnectionRow({
    super.key,
    required this.connection,
    required this.onOpenChat,
    required this.onRemove,
    required this.onBlock,
    required this.messageLabel,
    required this.removeLabel,
    required this.blockLabel,
    required this.sharedWorkspaceLabel,
  });

  final ChatConnection connection;
  final VoidCallback onOpenChat;
  final VoidCallback onRemove;
  final VoidCallback onBlock;
  final String messageLabel;
  final String removeLabel;
  final String blockLabel;
  final String sharedWorkspaceLabel;

  static ButtonStyle _flatAction(
    BuildContext context, {
    bool destructive = false,
  }) {
    final colors = Theme.of(context).colorScheme;
    final foreground = destructive ? colors.error : colors.primary;
    return TextButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      minimumSize: const Size(0, 40),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
      foregroundColor: foreground,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final user = connection.user;
    final subtitle = user.username.isNotEmpty
        ? '@${user.username}'
        : user.sharedWorkspace
        ? sharedWorkspaceLabel
        : null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Material(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  AppAvatar(size: 48, url: user.avatarUrl, name: user.name),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          user.name,
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            maxLines: 1,
                            softWrap: false,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      onPressed: onOpenChat,
                      style: _flatAction(context),
                      icon: const ChatIcon(
                        HugeIcons.strokeRoundedMessage01,
                        size: 18,
                      ),
                      label: Text(
                        messageLabel,
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  Expanded(
                    child: TextButton.icon(
                      onPressed: onRemove,
                      style: _flatAction(context),
                      icon: const ChatIcon(
                        HugeIcons.strokeRoundedUserRemove01,
                        size: 18,
                      ),
                      label: Text(
                        removeLabel,
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  Expanded(
                    child: TextButton.icon(
                      onPressed: onBlock,
                      style: _flatAction(context, destructive: true),
                      icon: const ChatIcon(
                        HugeIcons.strokeRoundedUnavailable,
                        size: 18,
                      ),
                      label: Text(
                        blockLabel,
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

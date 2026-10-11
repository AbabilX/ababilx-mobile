import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../shared/widgets/app_avatar.dart';
import '../chat-list/group_avatar_stack.dart';
import 'chat_recipient_target.dart';

/// One destination: picture, name, and the round tick that marks it picked.
class ChatRecipientRow extends StatelessWidget {
  const ChatRecipientRow({
    super.key,
    required this.target,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final ChatRecipientTarget target;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              _RecipientAvatar(target: target),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      target.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (target.subtitle.isNotEmpty)
                      Text(
                        target.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontSize: 13,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? colors.primary : Colors.transparent,
                  border: Border.all(
                    color: selected ? colors.primary : colors.outlineVariant,
                    width: 1.6,
                  ),
                ),
                child: selected
                    ? Center(
                        child: HugeIcon(
                          icon: HugeIcons.strokeRoundedTick02,
                          size: 16,
                          color: colors.onPrimary,
                          strokeWidth: 2.2,
                        ),
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecipientAvatar extends StatelessWidget {
  const _RecipientAvatar({required this.target});

  final ChatRecipientTarget target;

  @override
  Widget build(BuildContext context) {
    if (target.isGroup) {
      return GroupAvatarStack(
        avatars: target.memberAvatars,
        avatarUrl: target.avatarUrl,
        name: target.name,
        size: 44,
      );
    }
    return AppAvatar(
      size: 44,
      url: target.avatarUrl.isEmpty ? null : target.avatarUrl,
      name: target.name,
    );
  }
}

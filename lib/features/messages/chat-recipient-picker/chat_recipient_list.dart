import 'package:flutter/material.dart';

import '../../../shared/widgets/app_avatar.dart';
import '../chat-list/group_avatar_stack.dart';
import 'chat_recipient_target.dart';

/// Flat, sectioned destination list shared by Android shares and forwarding.
class ChatRecipientList extends StatelessWidget {
  const ChatRecipientList({
    super.key,
    required this.recent,
    required this.groups,
    required this.contacts,
    required this.selected,
    required this.enabled,
    required this.onToggle,
    required this.recentLabel,
    required this.groupsLabel,
    required this.contactsLabel,
    required this.emptyLabel,
  });

  final List<ChatRecipientTarget> recent;
  final List<ChatRecipientTarget> groups;
  final List<ChatRecipientTarget> contacts;
  final Set<String> selected;
  final bool enabled;
  final ValueChanged<ChatRecipientTarget> onToggle;
  final String recentLabel;
  final String groupsLabel;
  final String contactsLabel;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    if (recent.isEmpty && groups.isEmpty && contacts.isEmpty) {
      return Center(child: Text(emptyLabel));
    }
    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
      children: [
        _Section(label: recentLabel, targets: recent, child: this),
        _Section(label: groupsLabel, targets: groups, child: this),
        _Section(label: contactsLabel, targets: contacts, child: this),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.label,
    required this.targets,
    required this.child,
  });

  final String label;
  final List<ChatRecipientTarget> targets;
  final ChatRecipientList child;

  @override
  Widget build(BuildContext context) {
    if (targets.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
          child: Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        for (final target in targets)
          _RecipientRow(
            target: target,
            selected: child.selected.contains(target.selectionKey),
            enabled: child.enabled,
            onTap: () => child.onToggle(target),
          ),
      ],
    );
  }
}

class _RecipientRow extends StatelessWidget {
  const _RecipientRow({
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
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
          child: Row(
            children: [
              _RecipientAvatar(target: target),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      target.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleLarge,
                    ),
                    if (target.subtitle.isNotEmpty)
                      Text(
                        target.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? colors.primary : colors.surface,
                  border: Border.all(
                    color: selected ? colors.primary : colors.outline,
                    width: 2.5,
                  ),
                ),
                child: selected
                    ? Icon(Icons.check_rounded, color: colors.onPrimary)
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
        size: 56,
      );
    }
    return AppAvatar(
      size: 56,
      url: target.avatarUrl.isEmpty ? null : target.avatarUrl,
      name: target.name,
    );
  }
}

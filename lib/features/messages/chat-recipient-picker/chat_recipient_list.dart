import 'package:flutter/material.dart';

import 'chat_recipient_row.dart';
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
      return Center(
        child: Text(
          emptyLabel,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }
    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 8),
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
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        for (final target in targets)
          ChatRecipientRow(
            target: target,
            selected: child.selected.contains(target.selectionKey),
            enabled: child.enabled,
            onTap: () => child.onToggle(target),
          ),
      ],
    );
  }
}

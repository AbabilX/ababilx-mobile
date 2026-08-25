import 'package:flutter/material.dart';

import 'signal_message_menu.dart';

class SignalReactionBar extends StatelessWidget {
  const SignalReactionBar({super.key, required this.moreLabel});

  final String moreLabel;

  static const _emojis = ['👍', '❤️', '😂', '😮', '😢', '🎉'];

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surfaceContainerHigh,
      elevation: 8,
      borderRadius: BorderRadius.circular(28),
      child: SizedBox(
        height: 52,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            for (final emoji in _emojis)
              InkResponse(
                radius: 24,
                onTap: () =>
                    Navigator.pop(context, SignalMessageReaction(emoji)),
                child: Text(emoji, style: const TextStyle(fontSize: 25)),
              ),
            IconButton(
              tooltip: moreLabel,
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.add_circle_outline_rounded),
              onPressed: () =>
                  Navigator.pop(context, const SignalMessageReaction('')),
            ),
          ],
        ),
      ),
    );
  }
}

class SignalActionPanel extends StatelessWidget {
  const SignalActionPanel({
    super.key,
    required this.isMine,
    required this.showThread,
    required this.labels,
  });

  final bool isMine;
  final bool showThread;
  final Map<String, String> labels;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final actions = <(SignalMessageAction, IconData, String)>[
      (SignalMessageAction.reply, Icons.reply_rounded, labels['reply']!),
      (SignalMessageAction.forward, Icons.forward_rounded, labels['forward']!),
      (SignalMessageAction.copy, Icons.copy_rounded, labels['copy']!),
      if (showThread)
        (SignalMessageAction.thread, Icons.forum_outlined, labels['thread']!),
      if (isMine)
        (SignalMessageAction.edit, Icons.edit_outlined, labels['edit']!),
      if (isMine)
        (SignalMessageAction.delete, Icons.delete_outline, labels['delete']!),
    ];
    return Material(
      color: colors.surfaceContainerHigh,
      elevation: 8,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [for (final item in actions) _ActionRow(item: item)],
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.item});

  final (SignalMessageAction, IconData, String) item;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final destructive = item.$1 == SignalMessageAction.delete;
    final color = destructive ? colors.error : colors.onSurface;
    return InkWell(
      onTap: () => Navigator.pop(context, SignalMessageCommand(item.$1)),
      child: SizedBox(
        height: 48,
        child: Row(
          children: [
            const SizedBox(width: 18),
            Icon(item.$2, size: 22, color: color),
            const SizedBox(width: 18),
            Text(
              item.$3,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}

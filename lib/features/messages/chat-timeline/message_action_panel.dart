import 'package:flutter/material.dart';

import '../chat_icon.dart';
import 'message_menu.dart';
import 'message_menu_geometry.dart';
import 'message_menu_items.dart';

/// The context menu: 18dp corner, rows of a 24dp icon and BodyLarge with 16dp
/// side padding and 13dp above and below.
class MessageActionPanel extends StatelessWidget {
  const MessageActionPanel({super.key, required this.items});

  final List<MessageMenuItem> items;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surfaceContainerHigh,
      elevation: 20,
      shadowColor: Colors.black45,
      borderRadius: BorderRadius.circular(MessageMenuMetrics.menuRadius),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [for (final item in items) _ActionRow(item: item)],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.item});

  final MessageMenuItem item;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final destructive = item.action == MessageMenuAction.delete;
    final color = destructive ? colors.error : colors.onSurface;
    return InkWell(
      onTap: () => Navigator.pop(context, MessageMenuCommand(item.action)),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: MessageMenuMetrics.menuRowPadding,
          vertical: 13,
        ),
        child: Row(
          children: [
            ChatIcon(
              item.icon,
              size: MessageMenuMetrics.menuIconSize,
              color: color,
            ),
            const SizedBox(width: MessageMenuMetrics.menuIconGap),
            Expanded(
              child: Text(
                item.label,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../chat_icon.dart';
import 'signal_message_menu.dart';
import 'signal_message_menu_geometry.dart';
import 'signal_message_menu_items.dart';

/// The context menu: 18dp corner, rows of a 24dp icon and BodyLarge with 16dp
/// side padding and 13dp above and below.
class SignalActionPanel extends StatelessWidget {
  const SignalActionPanel({super.key, required this.items});

  final List<SignalMenuItem> items;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surfaceContainerHigh,
      elevation: 20,
      shadowColor: Colors.black45,
      borderRadius: BorderRadius.circular(SignalMenuMetrics.menuRadius),
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

  final SignalMenuItem item;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final destructive = item.action == SignalMessageAction.delete;
    final color = destructive ? colors.error : colors.onSurface;
    return InkWell(
      onTap: () => Navigator.pop(context, SignalMessageCommand(item.action)),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: SignalMenuMetrics.menuRowPadding,
          vertical: 13,
        ),
        child: Row(
          children: [
            ChatIcon(
              item.icon,
              size: SignalMenuMetrics.menuIconSize,
              color: color,
            ),
            const SizedBox(width: SignalMenuMetrics.menuIconGap),
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

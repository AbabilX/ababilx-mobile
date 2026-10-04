import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../chat_icon.dart';
import 'selection_action_bar.dart';
import 'selection_bar.dart';

/// The bottom of Telegram's selection mode, floating where the composer was:
/// Reply on the left while one message is picked, Forward on the right.
///
/// Each half keeps its side when the other is missing, so Forward does not
/// jump across the screen as a second message is ticked.
class SelectionBottomBar extends ConsumerWidget {
  const SelectionBottomBar({super.key, required this.conversationId});

  final String conversationId;

  /// What the list and the jump button must clear while the bar is up.
  static const reservedHeight = SelectionCapsule.height + 16;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = selectionItems(context, ref, conversationId);
    SelectionAction? of(SelectionActionKind kind) =>
        items.where((item) => item.kind == kind).firstOrNull;
    final reply = of(SelectionActionKind.reply);
    final forward = of(SelectionActionKind.forward);
    if (reply == null && forward == null) return const SizedBox.shrink();

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        child: Row(
          children: [
            Expanded(
              child: reply == null
                  ? const SizedBox.shrink()
                  : _LabelCapsule(item: reply, iconFirst: false),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: forward == null
                  ? const SizedBox.shrink()
                  : _LabelCapsule(item: forward, iconFirst: true),
            ),
          ],
        ),
      ),
    );
  }
}

class _LabelCapsule extends StatelessWidget {
  const _LabelCapsule({required this.item, required this.iconFirst});

  final SelectionAction item;
  final bool iconFirst;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurface;
    final icon = ChatIcon(item.icon, size: 20, color: color, strokeWidth: 1.5);
    final label = Flexible(
      child: Text(
        item.label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.titleSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
    return SelectionCapsule(
      onTap: item.onPressed,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: iconFirst
              ? [icon, const SizedBox(width: 8), label]
              : [label, const SizedBox(width: 8), icon],
        ),
      ),
    );
  }
}

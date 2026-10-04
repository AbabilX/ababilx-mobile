import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/localization/app_translations.dart';
import '../chat_icon.dart';
import 'message_selection.dart';
import 'selection_action_bar.dart';
import 'selection_bar.dart';

/// The top of Telegram's selection mode, floating over the timeline: a close
/// circle, the count in its own capsule, and the icon actions in a third.
///
/// It takes the chat header's place, so leaving the mode is always one tap
/// away however far the list is scrolled.
class SelectionTopBar extends ConsumerWidget {
  const SelectionTopBar({super.key, required this.conversationId});

  final String conversationId;

  /// What the list must clear below the status bar while the bar is up.
  static const reservedHeight = SelectionCapsule.height + 6;

  /// The icon capsule's buttons, in this order. Reply and Forward
  /// live in the bottom bar, and are not repeated here.
  static const _kinds = [
    SelectionActionKind.edit,
    SelectionActionKind.save,
    SelectionActionKind.copy,
    SelectionActionKind.delete,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final count = ref.watch(messageSelectionProvider).ids.length;
    final label = AppTranslations.translate(context, ref, 'chat_selected');
    final items = selectionItems(context, ref, conversationId);
    final icons = [
      for (final kind in _kinds) ...items.where((item) => item.kind == kind),
    ];

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
        child: Row(
          children: [
            Tooltip(
              message: MaterialLocalizations.of(context).closeButtonTooltip,
              child: SizedBox(
                width: SelectionCapsule.height,
                child: SelectionCapsule(
                  onTap: () =>
                      ref.read(messageSelectionProvider.notifier).clear(),
                  child: Center(
                    child: ChatIcon(
                      HugeIcons.strokeRoundedCancel01,
                      color: theme.colorScheme.onSurface,
                      strokeWidth: 1.5,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: SelectionCapsule(
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      '$count $label',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (icons.isNotEmpty) ...[
              const SizedBox(width: 6),
              SelectionCapsule(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final item in icons) SelectionIconButton(item: item),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

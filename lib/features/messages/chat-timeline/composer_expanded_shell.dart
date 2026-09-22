import 'package:flutter/material.dart';

import '../data/models/chat_models.dart';
import 'composer_attach.dart';

class ComposerExpandedShell extends StatelessWidget {
  const ComposerExpandedShell({
    super.key,
    required this.pending,
    required this.onRemove,
    required this.onAddPhoto,
    required this.field,
    this.onReorder,
    this.replyBanner,
    this.mentionPicker,
    this.selectionBadge,
  });

  final List<ChatAttachmentInput> pending;
  final ValueChanged<int> onRemove;
  final VoidCallback onAddPhoto;

  /// Drag-to-reorder the pending strip. Null leaves the tiles fixed.
  final void Function(int oldIndex, int newIndex)? onReorder;
  final Widget field;
  final Widget? replyBanner;
  final Widget? mentionPicker;

  /// Recents still staged while the text keyboard is up — see
  /// [ComposerRecentSelectionBadge].
  final Widget? selectionBadge;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final bar = Material(
      color: colors.surface,
      // Nested with the input pill (radius 26, 10px side inset): outer =
      // inner + padding, or the white corner reads flatter than the grey pill.
      borderRadius: const BorderRadius.vertical(top: Radius.circular(36)),
      clipBehavior: Clip.antiAlias,
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ?replyBanner,
            ?selectionBadge,
            if (pending.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                child: ComposerPendingPreviews(
                  items: pending,
                  onRemove: onRemove,
                  onAddPhoto: onAddPhoto,
                  onReorder: onReorder,
                ),
              ),
            field,
          ],
        ),
      ),
    );
    // Always the same Column with the bar keyed: returning the bar alone
    // when the popover is shut changed the tree's shape, which remounted the
    // text field and dropped the keyboard on every `@` typed or deleted.
    final picker = mentionPicker;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // The popover floats over the timeline as its own card; inside the
        // bar it stretched the bar's surface up behind it.
        if (picker != null)
          Padding(
            key: const ValueKey('mention-picker'),
            padding: const EdgeInsets.only(bottom: 6),
            child: picker,
          ),
        KeyedSubtree(key: const ValueKey('composer-bar'), child: bar),
      ],
    );
  }
}

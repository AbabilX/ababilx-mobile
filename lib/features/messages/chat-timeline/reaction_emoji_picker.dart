import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';

/// The "react with any emoji" sheet.
Future<String?> showReactionEmojiPicker(BuildContext context) {
  final scheme = Theme.of(context).colorScheme;
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: scheme.surface,
    builder: (ctx) => SafeArea(
      child: FractionallySizedBox(
        heightFactor: 0.62,
        child: EmojiPicker(
          onEmojiSelected: (_, emoji) => Navigator.pop(ctx, emoji.emoji),
          config: Config(
            checkPlatformCompatibility: true,
            emojiViewConfig: EmojiViewConfig(
              backgroundColor: scheme.surface,
              columns: 8,
              emojiSizeMax: 28,
            ),
            categoryViewConfig: CategoryViewConfig(
              backgroundColor: scheme.surface,
              iconColor: scheme.onSurfaceVariant,
              iconColorSelected: scheme.primary,
              indicatorColor: scheme.primary,
            ),
            bottomActionBarConfig: const BottomActionBarConfig(enabled: false),
            searchViewConfig: SearchViewConfig(
              backgroundColor: scheme.surface,
              buttonIconColor: scheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    ),
  );
}

import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../chat_icon.dart';

/// Focused Slack toolbar above keyboard.
class ComposerToolbar extends StatelessWidget {
  const ComposerToolbar({
    super.key,
    required this.sending,
    required this.canSend,
    required this.onShortcuts,
    required this.onEmoji,
    required this.onMention,
    required this.onFormat,
    required this.onAttachFile,
    required this.onAttachImage,
    required this.onSend,
  });

  final bool sending;
  final bool canSend;
  final VoidCallback onShortcuts;
  final VoidCallback onEmoji;
  final VoidCallback onMention;
  final VoidCallback onFormat;
  final VoidCallback onAttachFile;
  final VoidCallback onAttachImage;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final enabled = !sending;
    return Row(
      children: [
        _Btn(HugeIcons.strokeRoundedFlash, onShortcuts, enabled, muted),
        _Btn(HugeIcons.strokeRoundedSmile, onEmoji, enabled, muted),
        _Btn(HugeIcons.strokeRoundedAt, onMention, enabled, muted),
        _Btn(HugeIcons.strokeRoundedTextFont, onFormat, enabled, muted),
        const Spacer(),
        _Btn(HugeIcons.strokeRoundedAttachment, onAttachFile, enabled, muted),
        _Btn(HugeIcons.strokeRoundedImage01, onAttachImage, enabled, muted),
        IconButton(
          tooltip: 'Send',
          onPressed: enabled && canSend ? onSend : null,
          icon: sending
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : ChatIcon(
                  HugeIcons.strokeRoundedSent,
                  color: canSend
                      ? Theme.of(context).colorScheme.primary
                      : muted.withValues(alpha: 0.45),
                ),
        ),
      ],
    );
  }
}

class _Btn extends StatelessWidget {
  const _Btn(this.icon, this.onTap, this.enabled, this.color);
  final List<List<dynamic>> icon;
  final VoidCallback onTap;
  final bool enabled;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: enabled ? onTap : null,
      icon: ChatIcon(icon, size: 22, color: color),
    );
  }
}

/// Full mobile-style emoji keyboard (not a fixed shortlist).
Future<void> showEmojiPicker(
  BuildContext context,
  TextEditingController controller,
) async {
  final scheme = Theme.of(context).colorScheme;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: scheme.surface,
    builder: (ctx) => SafeArea(
      child: SizedBox(
        height: 320,
        child: EmojiPicker(
          textEditingController: controller,
          config: Config(
            height: 320,
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

/// Inline emoji panel under the composer (toggles with soft keyboard).
class ComposerEmojiPanel extends StatelessWidget {
  const ComposerEmojiPanel({
    super.key,
    required this.controller,
    this.height = 280,
  });

  final TextEditingController controller;
  final double height;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: height,
      child: EmojiPicker(
        textEditingController: controller,
        config: Config(
          height: height,
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
    );
  }
}

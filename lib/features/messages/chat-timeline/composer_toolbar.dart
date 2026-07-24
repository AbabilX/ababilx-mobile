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

Future<void> showEmojiPicker(
  BuildContext context,
  ValueChanged<String> onPick,
) async {
  const emojis = ['👍', '❤️', '😂', '🎉', '🔥', '👀', '✅', '🙏'];
  final picked = await showModalBottomSheet<String>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: emojis
              .map(
                (e) => InkWell(
                  onTap: () => Navigator.pop(ctx, e),
                  child: Text(e, style: const TextStyle(fontSize: 28)),
                ),
              )
              .toList(),
        ),
      ),
    ),
  );
  if (picked != null) onPick(picked);
}

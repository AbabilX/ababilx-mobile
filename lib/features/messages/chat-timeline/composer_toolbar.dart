import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../chat_icon.dart';

class ComposerToolbar extends StatelessWidget {
  const ComposerToolbar({
    super.key,
    required this.sending,
    required this.onAttach,
    required this.onFormat,
    required this.onEmoji,
    required this.onMention,
    required this.onSend,
  });

  final bool sending;
  final VoidCallback onAttach;
  final VoidCallback onFormat;
  final VoidCallback onEmoji;
  final VoidCallback onMention;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: sending ? null : onAttach,
          icon: const ChatIcon(HugeIcons.strokeRoundedAddCircle),
          tooltip: 'Attach',
        ),
        IconButton(
          onPressed: sending ? null : onFormat,
          icon: const ChatIcon(HugeIcons.strokeRoundedTextBold),
          tooltip: 'Bold',
        ),
        IconButton(
          onPressed: sending ? null : onEmoji,
          icon: const ChatIcon(HugeIcons.strokeRoundedSmile),
          tooltip: 'Emoji',
        ),
        IconButton(
          onPressed: sending ? null : onMention,
          icon: const ChatIcon(HugeIcons.strokeRoundedAt),
          tooltip: 'Mention',
        ),
        const Spacer(),
        IconButton.filled(
          onPressed: sending ? null : onSend,
          icon: sending
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const ChatIcon(HugeIcons.strokeRoundedSent),
        ),
      ],
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

import 'package:flutter/material.dart';

import '../data/models/chat_models.dart';
import '../tiptap_plain_text.dart';

class ComposerReplyBanner extends StatelessWidget {
  const ComposerReplyBanner({
    super.key,
    required this.message,
    required this.onCancel,
  });

  final ChatMessage message;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final name = message.userName ?? 'someone';
    final plainText = tiptapToPlainText(message.body);

    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceContainerHigh.withValues(alpha: 0.6),
        border: Border(
          left: BorderSide(
            color: colors.primary,
            width: 3.5,
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Icon(
            Icons.reply,
            size: 18,
            color: colors.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      'Replying to ',
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    Flexible(
                      child: Text(
                        name,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: colors.primary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if (plainText.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    plainText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: colors.onSurface,
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(
              minWidth: 28,
              minHeight: 28,
            ),
            splashRadius: 16,
            onPressed: onCancel,
            tooltip: 'Cancel reply',
          ),
        ],
      ),
    );
  }
}

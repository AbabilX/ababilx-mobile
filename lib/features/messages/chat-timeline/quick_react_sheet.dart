import 'package:flutter/material.dart';

const kQuickEmojis = ['👍', '❤️', '😂', '😮', '😢', '🎉', '🔥', '👀'];

Future<String?> showQuickReactSheet(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    builder: (ctx) {
      final colors = Theme.of(ctx).colorScheme;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Add reaction',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: colors.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final e in kQuickEmojis)
                    InkWell(
                      onTap: () => Navigator.pop(ctx, e),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 48,
                        height: 48,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: colors.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(e, style: const TextStyle(fontSize: 24)),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

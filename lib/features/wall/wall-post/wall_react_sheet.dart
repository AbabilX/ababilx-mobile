import 'package:flutter/material.dart';

/// Web wall picker set ([wall-post-card.tsx] hover strip) plus clap.
const kWallReactEmojis = ['👏', '👍', '❤️', '🎉', '💡', '🚀'];

/// Full-width bottom sheet — hold Clap to pick another emoji.
Future<String?> showWallReactSheet(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) {
      final colors = Theme.of(ctx).colorScheme;
      final width = MediaQuery.sizeOf(ctx).width;
      return SafeArea(
        child: SizedBox(
          width: width,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colors.outlineVariant,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Add reaction',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: colors.onSurface,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    for (final e in kWallReactEmojis)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Material(
                            color: colors.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(14),
                            child: InkWell(
                              onTap: () => Navigator.pop(ctx, e),
                              borderRadius: BorderRadius.circular(14),
                              child: SizedBox(
                                height: 52,
                                child: Center(
                                  child: Text(
                                    e,
                                    style: const TextStyle(fontSize: 26),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../chat_icon.dart';
import '../data/models/chat_models.dart';

class ReactionRow extends StatelessWidget {
  const ReactionRow({
    super.key,
    required this.reactions,
    required this.onToggle,
    required this.onAdd,
  });

  final List<ChatReactionGroup> reactions;
  final ValueChanged<String> onToggle;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ...reactions.map((r) {
            final active = r.reactedByMe;
            return InkWell(
              onTap: () => onToggle(r.emoji),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: active
                      ? colors.primary.withValues(alpha: 0.16)
                      : colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: active
                        ? colors.primary.withValues(alpha: 0.45)
                        : colors.outlineVariant.withValues(alpha: 0.4),
                  ),
                ),
                child: Text(
                  '${r.emoji} ${r.count}',
                  style: const TextStyle(fontSize: 13, height: 1.1),
                ),
              ),
            );
          }),
          InkWell(
            onTap: onAdd,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: colors.outlineVariant.withValues(alpha: 0.55),
                ),
              ),
              child: Center(
                child: ChatIcon(
                  HugeIcons.strokeRoundedSmile,
                  size: 16,
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

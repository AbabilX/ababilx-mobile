import 'package:flutter/material.dart';

import '../data/models/chat_models.dart';

class ReactionRow extends StatelessWidget {
  const ReactionRow({super.key, required this.reactions});
  final List<ChatReactionGroup> reactions;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        children: reactions
            .map(
              (r) => Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: r.reactedByMe
                      ? colors.primaryContainer
                      : colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  '${r.emoji} ${r.count}',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

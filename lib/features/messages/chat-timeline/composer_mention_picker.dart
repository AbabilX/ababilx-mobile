import 'package:flutter/material.dart';

import '../../../shared/widgets/app_avatar.dart';

class MentionCandidate {
  const MentionCandidate({
    required this.userId,
    required this.displayName,
    this.avatarUrl,
  });

  final String userId;
  final String displayName;
  final String? avatarUrl;
}

class ComposerMentionPicker extends StatelessWidget {
  const ComposerMentionPicker({
    super.key,
    required this.candidates,
    required this.onSelect,
  });

  final List<MentionCandidate> candidates;
  final ValueChanged<MentionCandidate> onSelect;

  @override
  Widget build(BuildContext context) {
    if (candidates.isEmpty) return const SizedBox.shrink();
    final colors = Theme.of(context).colorScheme;

    return Container(
      constraints: const BoxConstraints(maxHeight: 210),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHigh,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: Row(
              children: [
                Icon(
                  Icons.alternate_email_rounded,
                  size: 14,
                  color: colors.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  'Mention member',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: colors.primary,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: candidates.length,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                indent: 48,
                color: colors.outlineVariant.withOpacity(0.2),
              ),
              itemBuilder: (ctx, index) {
                final c = candidates[index];
                return ListTile(
                  dense: true,
                  visualDensity: VisualDensity.compact,
                  leading: AppAvatar(
                    size: 30,
                    url: c.avatarUrl,
                    name: c.displayName,
                  ),
                  title: Text(
                    c.displayName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  onTap: () => onSelect(c),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import 'composer_mention_tile.dart';

class MentionCandidate {
  const MentionCandidate({
    required this.userId,
    required this.displayName,
    this.avatarUrl,
    this.isInChannel = true,
    this.isAll = false,
  });

  /// The `@all` row. Carries no user id: picking it mentions every member.
  static const all = MentionCandidate(
    userId: '',
    displayName: 'all',
    isAll: true,
  );

  final String userId;
  final String displayName;
  final String? avatarUrl;
  final bool isInChannel;
  final bool isAll;
}

/// The `@` popover, laid out like WhatsApp's: `@all` first, then members with
/// their photo and status, then a rule and the caller's connections who are
/// not in this group.
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

    final inChannel = candidates.where((c) => c.isInChannel).toList();
    final outsiders = candidates.where((c) => !c.isInChannel).toList();

    return Container(
      constraints: const BoxConstraints(maxHeight: 300),
      margin: const EdgeInsets.symmetric(horizontal: 8),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          for (final c in inChannel) MentionTile(candidate: c, onTap: onSelect),
          if (outsiders.isNotEmpty) ...[
            if (inChannel.isNotEmpty)
              Divider(
                height: 17,
                thickness: 1,
                indent: 16,
                endIndent: 16,
                color: colors.outlineVariant,
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 4),
              child: Text(
                'Outsiders',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
            for (final c in outsiders)
              MentionTile(candidate: c, onTap: onSelect),
          ],
        ],
      ),
    );
  }
}

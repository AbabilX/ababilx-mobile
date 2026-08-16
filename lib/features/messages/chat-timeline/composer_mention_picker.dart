import 'package:flutter/material.dart';

import '../../../shared/widgets/app_avatar.dart';

class MentionCandidate {
  const MentionCandidate({
    required this.userId,
    required this.displayName,
    this.avatarUrl,
    this.isInChannel = true,
  });

  final String userId;
  final String displayName;
  final String? avatarUrl;
  final bool isInChannel;
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

    final inChannel = candidates.where((c) => c.isInChannel).toList();
    final notInChannel = candidates.where((c) => !c.isInChannel).toList();

    return Container(
      constraints: const BoxConstraints(maxHeight: 240),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHigh,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
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
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 4),
              children: [
                if (inChannel.isNotEmpty) ...[
                  if (notInChannel.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
                      child: Text(
                        'MEMBERS IN THIS CHANNEL',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: colors.onSurfaceVariant,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ...inChannel.map((c) => _buildCandidateTile(context, c)),
                ],
                if (inChannel.isNotEmpty && notInChannel.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Divider(
                      height: 1,
                      thickness: 1.5,
                      color: colors.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
                ],
                if (notInChannel.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
                    child: Text(
                      'NOT IN THIS CHANNEL',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: colors.error.withValues(alpha: 0.9),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  ...notInChannel.map((c) => _buildCandidateTile(context, c)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCandidateTile(BuildContext context, MentionCandidate c) {
    final colors = Theme.of(context).colorScheme;
    return ListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      leading: AppAvatar(size: 30, url: c.avatarUrl, name: c.displayName),
      title: Text(
        c.displayName,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
      subtitle: !c.isInChannel
          ? Text(
              'Not in channel',
              style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant),
            )
          : null,
      onTap: () => onSelect(c),
    );
  }
}

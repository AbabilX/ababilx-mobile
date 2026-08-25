import 'package:flutter/material.dart';

import '../../../../shared/widgets/app_avatar.dart';
import '../providers/group_call_state.dart';

/// Avatar tiles for everyone in the call — mirrors web
/// `group-call-participant-grid.tsx`, with a speaking ring and a mute badge.
class GroupParticipantGrid extends StatelessWidget {
  const GroupParticipantGrid({
    super.key,
    required this.participants,
    this.compact = false,
  });

  final List<GroupParticipantView> participants;

  /// Compact = the filmstrip shown beside a screen share.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (participants.isEmpty) {
      return Center(
        child: Text(
          'Waiting for others to join…',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    if (compact) {
      return ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        itemCount: participants.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, index) =>
            SizedBox(width: 120, child: _Tile(participants[index], true)),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(4),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: participants.length <= 1 ? 1 : 2,
        childAspectRatio: participants.length <= 1 ? 0.9 : 1,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: participants.length,
      itemBuilder: (_, index) => _Tile(participants[index], false),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile(this.participant, this.compact);

  final GroupParticipantView participant;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final avatarSize = compact ? 40.0 : 72.0;
    final label = participant.isLocal
        ? '${participant.name} (You)'
        : participant.name;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: participant.isSpeaking
              ? colors.primary
              : colors.outlineVariant,
          width: participant.isSpeaking ? 2 : 1,
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          AppAvatar(
            size: avatarSize,
            url: participant.avatarUrl,
            name: participant.name,
          ),
          Positioned(
            left: 8,
            right: 8,
            bottom: 8,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: colors.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (participant.isMuted) ...[
                  const SizedBox(width: 4),
                  Icon(Icons.mic_off_rounded, size: 14, color: colors.error),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

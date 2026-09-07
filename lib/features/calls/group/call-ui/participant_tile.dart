import 'package:flutter/material.dart';

import '../../../../shared/widgets/app_avatar.dart';
import '../call_icons.dart';
import '../providers/group_call_state.dart';
import 'call_surface.dart';

enum CallTileSize { small, medium, large }

/// One person in the call. There is no camera, so the tile carries the two
/// things that actually change during an audio call: who is talking, and who
/// has a hand up.
class ParticipantTile extends StatelessWidget {
  const ParticipantTile({
    super.key,
    required this.participant,
    this.size = CallTileSize.medium,
    this.handRaised = false,
    this.reaction,
  });

  final GroupParticipantView participant;
  final CallTileSize size;
  final bool handRaised;
  final String? reaction;

  double get _avatarSize => switch (size) {
    CallTileSize.small => 40,
    CallTileSize.medium => 62,
    CallTileSize.large => 108,
  };

  @override
  Widget build(BuildContext context) {
    final palette = CallColors.of(context);
    final speaking = participant.isSpeaking && !participant.isMuted;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.tile,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: speaking ? palette.accent : Colors.transparent,
          width: 2,
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          AppAvatar(
            size: _avatarSize,
            url: participant.avatarUrl,
            name: participant.name,
          ),
          if (handRaised)
            Positioned(
              top: 6,
              right: 6,
              child: _Badge(
                child: CallIcon(
                  CallIcons.raiseHand,
                  size: 16,
                  color: palette.hand,
                ),
              ),
            ),
          if (reaction != null)
            Positioned(
              top: 6,
              left: 6,
              child: _Badge(
                child: Text(reaction!, style: const TextStyle(fontSize: 16)),
              ),
            ),
          Positioned(
            left: 6,
            right: 6,
            bottom: 6,
            child: _NameChip(participant: participant),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    width: 28,
    height: 28,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: CallColors.of(context).chip,
      shape: BoxShape.circle,
    ),
    child: child,
  );
}

class _NameChip extends StatelessWidget {
  const _NameChip({required this.participant});
  final GroupParticipantView participant;

  @override
  Widget build(BuildContext context) {
    final palette = CallColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: palette.chip,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (participant.isMuted) ...[
            CallIcon(CallIcons.micMuted, size: 13, color: palette.muted),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              participant.isLocal
                  ? '${participant.name} (You)'
                  : participant.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: palette.onChip, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

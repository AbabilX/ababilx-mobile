import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../shared/widgets/app_avatar.dart';
import '../call_icons.dart';
import '../providers/group_call_state.dart';
import 'call_surface.dart';

/// One person in the call. There is no camera, so the tile carries the two
/// things that actually change during an audio call: who is talking, and who
/// has a hand up.
///
/// The avatar is sized from the tile's own box rather than a caller-supplied
/// enum. The enum defaulted to a fixed 62dp and the grid never overrode it, so
/// a solo call drew a 62dp speck in a tile the width of the screen.
class ParticipantTile extends StatelessWidget {
  const ParticipantTile({
    super.key,
    required this.participant,
    this.handRaised = false,
    this.reaction,
  });

  final GroupParticipantView participant;
  final bool handRaised;
  final String? reaction;

  @override
  Widget build(BuildContext context) {
    final palette = CallColors.of(context);
    final speaking = participant.isSpeaking && !participant.isMuted;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        final shortest = height.isFinite ? math.min(width, height) : width;
        final avatar = (shortest * 0.40).clamp(36.0, 128.0);
        final badge = avatar < 52 ? 22.0 : 28.0;
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
                size: avatar,
                url: participant.avatarUrl,
                name: participant.name,
              ),
              if (handRaised)
                Positioned(
                  top: 6,
                  right: 6,
                  child: _Badge(
                    size: badge,
                    child: CallIcon(
                      CallIcons.raiseHand,
                      size: badge * 0.57,
                      color: palette.hand,
                    ),
                  ),
                ),
              if (reaction != null)
                Positioned(
                  top: 6,
                  left: 6,
                  child: _Badge(
                    size: badge,
                    child: Text(
                      reaction!,
                      style: TextStyle(fontSize: badge * 0.57),
                    ),
                  ),
                ),
              // Aligned, not stretched: `Positioned` with both left and right
              // set hands the chip a tight width, so it filled the tile edge to
              // edge and read as a disabled text field rather than a label.
              Positioned(
                left: 8,
                right: 8,
                bottom: 8,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _NameChip(participant: participant),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.child, required this.size});
  final Widget child;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: CallColors.of(context).chip,
      shape: BoxShape.circle,
    ),
    child: child,
  );
}

/// The name label, so a layout test can assert it hugs its text instead of
/// stretching the width of the tile.
const Key callNameChipKey = Key('call-name-chip');

class _NameChip extends StatelessWidget {
  const _NameChip({required this.participant});
  final GroupParticipantView participant;

  @override
  Widget build(BuildContext context) {
    final palette = CallColors.of(context);
    return Container(
      key: callNameChipKey,
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

import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';

import '../providers/group_call_state.dart';

/// The shared screen on stage — mirrors web `group-call-screen-stage.tsx`.
class GroupScreenStage extends StatelessWidget {
  const GroupScreenStage({super.key, required this.screen});

  final GroupScreenView screen;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: ColoredBox(
        color: Colors.black,
        child: Stack(
          children: [
            Positioned.fill(
              child: VideoTrackRenderer(
                screen.track,
                // Contain, so shared code and slides are never cropped.
                fit: VideoViewFit.contain,
              ),
            ),
            Positioned(
              left: 12,
              top: 12,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.surface.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: colors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        screen.isLocal
                            ? 'You are sharing'
                            : "${screen.participantName}'s screen",
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

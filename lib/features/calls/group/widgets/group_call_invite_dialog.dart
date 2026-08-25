import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/app_avatar.dart';
import '../../widgets/call_ring_pulse.dart';
import '../../widgets/incoming_call_actions.dart';
import '../data/models/group_call.dart';
import '../providers/group_call_provider.dart';

/// Full-screen ringing surface for a channel group call.
///
/// Deliberately the same layout as the incoming 1:1 call screen — gradient,
/// large avatar, name, status line, then Decline and Join at the bottom — so a
/// ringing channel call is not a small card while a DM takes over the display.
///
/// Deny is local only: the call keeps running for everyone else and the
/// channel header still offers "Join".
class GroupCallInviteDialog extends ConsumerWidget {
  const GroupCallInviteDialog({super.key, required this.call});

  final GroupCall call;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(groupCallProvider.notifier);
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Material(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [colors.primaryContainer, colors.surface, colors.surface],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
            child: Column(
              children: [
                const Spacer(),
                CallRingPulse(
                  size: 120,
                  child: AppAvatar(
                    size: 120,
                    url: call.starterAvatarUrl,
                    name: call.title,
                    border: Border.all(color: colors.outlineVariant, width: 2),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  call.title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: text.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'AbabilX channel call',
                  style: text.labelLarge?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '${call.starterName} started a group call',
                  textAlign: TextAlign.center,
                  style: text.titleMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (call.participantCount > 0) ...[
                  const SizedBox(height: 10),
                  _ParticipantCount(count: call.participantCount),
                ],
                const Spacer(flex: 2),
                IncomingCallActions(
                  declineLabel: 'Deny',
                  acceptLabel: 'Join',
                  acceptIcon: Icons.headset_mic_rounded,
                  onDecline: notifier.declineInvite,
                  onAccept: notifier.acceptInvite,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ParticipantCount extends StatelessWidget {
  const _ParticipantCount({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.group_rounded, size: 16, color: colors.onSurfaceVariant),
        const SizedBox(width: 6),
        Text(
          '$count already in call',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
        ),
      ],
    );
  }
}

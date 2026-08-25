import 'package:flutter/material.dart';

import '../../../shared/widgets/app_avatar.dart';
import '../widgets/call_ring_pulse.dart';
import '../widgets/incoming_call_actions.dart';

/// The screen a ringing call shows before it is answered.
///
/// Deliberately not the in-call layout: while the phone is ringing there are
/// exactly two things to do, so the caller fills the screen and Decline /
/// Accept sit at the bottom edge under the thumbs, the way every phone dialler
/// — and Signal — presents it. In-call controls only appear once the call is
/// actually up.
class IncomingCallView extends StatelessWidget {
  const IncomingCallView({
    super.key,
    required this.peerName,
    required this.peerAvatar,
    required this.onDecline,
    required this.onAccept,
    this.subtitle = 'AbabilX voice call',
  });

  final String peerName;
  final String? peerAvatar;
  final String subtitle;
  final VoidCallback onDecline;
  final VoidCallback onAccept;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            colors.primaryContainer,
            colors.surface,
            colors.surfaceContainerHighest,
          ],
          stops: const [0, 0.55, 1],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 2),
            CallRingPulse(
              size: 132,
              child: AppAvatar(
                size: 132,
                url: peerAvatar,
                name: peerName,
                border: Border.all(color: colors.outlineVariant, width: 2),
              ),
            ),
            const SizedBox(height: 28),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                peerName,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              subtitle,
              style: textTheme.titleSmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const Spacer(flex: 3),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: IncomingCallActions(
                onDecline: onDecline,
                onAccept: onAccept,
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

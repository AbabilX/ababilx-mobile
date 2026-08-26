import 'package:flutter/material.dart';

import '../../../shared/widgets/app_avatar.dart';
import '../widgets/call_backdrop.dart';
import '../widgets/call_control_button.dart';
import '../widgets/call_ring_pulse.dart';
import '../widgets/call_top_bar.dart' show callTextShadow;

/// The screen a ringing call shows before it is answered.
///
/// Laid out the way Signal's `IncomingCallScreen` is, because that layout is
/// what a phone dialler has taught everyone to expect: the caller's own blurred
/// photo fills the window, a call-type line names what is ringing, the person
/// sits in the middle, and Decline / Answer sit apart at the bottom edge under
/// the thumbs. In-call controls appear only once the call is actually up —
/// while it rings there are exactly two things to do.
///
/// No top bar and no back affordance on purpose: on a ringing screen every
/// exit is a decision, and both decisions already have a button.
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
    final textTheme = Theme.of(context).textTheme;
    final landscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;

    return Stack(
      fit: StackFit.expand,
      children: [
        CallBackdrop(avatarUrl: peerAvatar),
        SafeArea(
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.only(
                  top: landscape ? 0 : 22,
                  bottom: landscape ? 20 : 30,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.phone_in_talk_rounded,
                      size: 18,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      subtitle,
                      style: textTheme.bodyMedium?.copyWith(
                        color: Colors.white,
                        shadows: callTextShadow,
                      ),
                    ),
                  ],
                ),
              ),
              CallRingPulse(
                size: 96,
                child: AppAvatar(
                  size: 96,
                  url: peerAvatar,
                  name: peerName,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.35),
                    width: 2,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Text(
                  peerName,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style:
                      (landscape
                              ? textTheme.titleLarge
                              : textTheme.headlineMedium)
                          ?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            shadows: callTextShadow,
                          ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Incoming call…',
                style: textTheme.bodyMedium?.copyWith(
                  color: Colors.white70,
                  shadows: callTextShadow,
                ),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.fromLTRB(48, 0, 48, 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    CallControlButton.large(
                      icon: Icons.call_end_rounded,
                      label: 'Decline',
                      background: const Color(0xFFE04B4B),
                      foreground: Colors.white,
                      onPressed: onDecline,
                    ),
                    CallControlButton.large(
                      icon: Icons.call_rounded,
                      label: 'Answer',
                      background: const Color(0xFF3AB55B),
                      foreground: Colors.white,
                      onPressed: onAccept,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

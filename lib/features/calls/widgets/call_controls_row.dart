import 'package:flutter/material.dart';

import '../providers/voice_call_state.dart';
import 'call_control_button.dart';

/// The row of controls along the bottom of a live call.
///
/// Signal keeps this row to one line of equal circles with the hangup in red,
/// and disables rather than hides a control that is momentarily unavailable —
/// so the row never reflows under your thumb mid-call.
class CallControlsRow extends StatelessWidget {
  const CallControlsRow({
    super.key,
    required this.call,
    required this.onToggleMute,
    required this.onToggleScreenShare,
    required this.onToggleSpeaker,
    required this.onHangUp,
  });

  final VoiceCallState call;
  final VoidCallback onToggleMute;
  final VoidCallback onToggleScreenShare;
  final VoidCallback onToggleSpeaker;
  final VoidCallback onHangUp;

  /// True once the media session exists — before that, toggling mute or the
  /// speaker has nothing to act on.
  bool get _live => call.active && call.phase != VoiceCallPhase.starting;

  /// You may start sharing only when connected, and only while the other side
  /// is not already sharing; stopping your own share is always allowed.
  bool get _canShare =>
      call.phase == VoiceCallPhase.connected &&
      (call.remoteScreenStream == null || call.screenSharing);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        CallControlButton(
          icon: call.muted ? Icons.mic_off_rounded : Icons.mic_rounded,
          label: call.muted ? 'Unmute' : 'Mute',
          selected: call.muted,
          onPressed: _live ? onToggleMute : null,
        ),
        CallControlButton(
          icon: call.screenSharing
              ? Icons.stop_screen_share_rounded
              : Icons.screen_share_rounded,
          label: call.screenSharing ? 'Stop' : 'Share',
          selected: call.screenSharing,
          onPressed: _canShare ? onToggleScreenShare : null,
        ),
        CallControlButton(
          icon: call.speaker ? Icons.volume_up_rounded : Icons.hearing_rounded,
          label: 'Speaker',
          selected: call.speaker,
          onPressed: _live ? onToggleSpeaker : null,
        ),
        CallControlButton(
          icon: Icons.call_end_rounded,
          label: 'End',
          background: const Color(0xFFE04B4B),
          foreground: Colors.white,
          onPressed: _live ? onHangUp : null,
        ),
      ],
    );
  }
}

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
    required this.onToggleCamera,
    required this.onToggleScreenShare,
    required this.onToggleSpeaker,
    required this.onHangUp,
  });

  final VoiceCallState call;
  final VoidCallback onToggleMute;
  final VoidCallback onToggleCamera;
  final VoidCallback onToggleScreenShare;
  final VoidCallback onToggleSpeaker;
  final VoidCallback onHangUp;

  /// True once the media session exists — before that, toggling mute or the
  /// speaker has nothing to act on.
  bool get _live => call.active && call.phase != VoiceCallPhase.starting;

  /// Sharing needs a connected call and nothing else. Pressing this while the
  /// other side is sharing TAKES OVER — the button used to be greyed out
  /// there, which read as "screen sharing is broken on this call".
  bool get _canShare => call.phase == VoiceCallPhase.connected;

  /// The other side holds the one shared screen a 1:1 call has.
  bool get _takingOver =>
      call.remoteScreenStream != null && !call.screenSharing;

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
          icon: call.cameraOn
              ? Icons.videocam_rounded
              : Icons.videocam_off_rounded,
          label: call.cameraOn ? 'Camera' : 'Camera',
          selected: call.cameraOn,
          onPressed: call.phase == VoiceCallPhase.connected
              ? onToggleCamera
              : null,
        ),
        CallControlButton(
          icon: call.screenSharing
              ? Icons.stop_screen_share_rounded
              : Icons.screen_share_rounded,
          label: call.screenSharing
              ? 'Stop'
              : _takingOver
              ? 'Take over'
              : 'Share',
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

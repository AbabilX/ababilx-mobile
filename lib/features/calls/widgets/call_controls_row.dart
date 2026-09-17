import 'package:flutter/material.dart';

import '../../../core/localization/app_translations.dart';
import '../providers/voice_call_state.dart';
import 'call_control_circle.dart';

/// The call's control deck: four round toggles across the full width, with a
/// larger End circle under them.
///
/// The circles are sized by the screen, not by a constant — each takes a
/// quarter of the row, so they are a good deal bigger than the old 64dp pair
/// of stacked rows and the deck is one glance instead of three. That is
/// Material 3 Expressive's argument for its own media controls: on a screen
/// whose entire purpose is a handful of choices, the choices are the layout.
///
/// End stays the biggest thing on the deck and keeps the error role in both
/// states. The set never changes shape mid-call: a control that cannot be used
/// yet is dimmed in place, so nothing moves under a thumb already reaching for
/// it.
class CallControlsRow extends StatelessWidget {
  const CallControlsRow({
    super.key,
    required this.call,
    required this.onToggleMute,
    required this.onToggleCamera,
    required this.onToggleScreenShare,
    required this.onToggleSpeaker,
    required this.onHangUp,
    this.lang = 'en',
  });

  final VoiceCallState call;
  final VoidCallback onToggleMute;
  final VoidCallback onToggleCamera;
  final VoidCallback onToggleScreenShare;
  final VoidCallback onToggleSpeaker;
  final VoidCallback onHangUp;
  final String lang;

  bool get _live => call.active && call.phase != VoiceCallPhase.starting;
  bool get _connected => call.phase == VoiceCallPhase.connected;
  bool get _takingOver =>
      call.remoteScreenStream != null && !call.screenSharing;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    String tr(String key) => AppTranslations.of(lang, key);

    final controls = <Widget>[
      CallControlCircle(
        icon: call.muted ? Icons.mic_off_rounded : Icons.mic_rounded,
        label: tr(call.muted ? 'group_unmute' : 'group_mute'),
        selected: call.muted,
        onPressed: _live ? onToggleMute : null,
      ),
      CallControlCircle(
        icon: call.speaker ? Icons.volume_up_rounded : Icons.hearing_rounded,
        label: tr('call_control_speaker'),
        selected: call.speaker,
        onPressed: _live ? onToggleSpeaker : null,
      ),
      CallControlCircle(
        icon: call.cameraOn
            ? Icons.videocam_rounded
            : Icons.videocam_off_rounded,
        label: tr('chat_camera'),
        selected: call.cameraOn,
        onPressed: _connected ? onToggleCamera : null,
      ),
      CallControlCircle(
        icon: call.screenSharing
            ? Icons.stop_screen_share_rounded
            : Icons.screen_share_rounded,
        label: tr(
          call.screenSharing
              ? 'call_control_stop'
              : _takingOver
              ? 'call_control_take_over'
              : 'call_control_share',
        ),
        selected: call.screenSharing,
        onPressed: _connected ? onToggleScreenShare : null,
      ),
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          // Top-aligned, so a two-line label under one circle cannot push its
          // neighbours out of line.
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < controls.length; i++) ...[
              if (i > 0) const SizedBox(width: 12),
              Expanded(child: controls[i]),
            ],
          ],
        ),
        const SizedBox(height: 24),
        CallControlCircle(
          icon: Icons.call_end_rounded,
          label: tr('call_control_end'),
          background: colors.error,
          foreground: colors.onError,
          fixedSize: 96,
          iconScale: 0.38,
          onPressed: call.active ? onHangUp : null,
        ),
      ],
    );
  }
}

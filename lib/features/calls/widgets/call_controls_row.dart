import 'package:flutter/material.dart';

import '../../../core/localization/app_translations.dart';
import '../providers/voice_call_state.dart';
import 'call_glass_circle.dart';
import 'call_overlay_metrics.dart';

/// Four glass toggles in one row, plus a larger End circle underneath.
///
/// Order is Mute → Camera → Screen Share → Speaker — matching the call
/// overlay mock. A control that is not usable yet stays in place and dims.
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
    this.endLabel,
  });

  final VoiceCallState call;
  final VoidCallback onToggleMute;
  final VoidCallback onToggleCamera;
  final VoidCallback onToggleScreenShare;
  final VoidCallback onToggleSpeaker;
  final VoidCallback onHangUp;
  final String lang;

  /// Defaults to localized "End". Incoming uses "Decline" instead.
  final String? endLabel;

  bool get _live => call.active && call.phase != VoiceCallPhase.starting;
  bool get _connected => call.phase == VoiceCallPhase.connected;
  bool get _takingOver =>
      call.remoteScreenStream != null && !call.screenSharing;

  @override
  Widget build(BuildContext context) {
    final m = CallOverlayMetrics.of(context);
    String tr(String key) => AppTranslations.of(lang, key);
    final hangLabel = endLabel ?? tr('call_control_end');

    final controls = <Widget>[
      CallGlassCircle(
        icon: call.muted ? Icons.mic_off_rounded : Icons.mic_rounded,
        label: tr(call.muted ? 'group_unmute' : 'group_mute'),
        selected: call.muted,
        diameter: m.controlDiameter,
        iconSize: m.controlIcon,
        labelFontSize: m.controlLabelFont,
        onPressed: _live ? onToggleMute : null,
      ),
      CallGlassCircle(
        icon: call.cameraOn
            ? Icons.videocam_rounded
            : Icons.videocam_off_rounded,
        label: tr('chat_camera'),
        selected: call.cameraOn,
        diameter: m.controlDiameter,
        iconSize: m.controlIcon,
        labelFontSize: m.controlLabelFont,
        onPressed: _connected ? onToggleCamera : null,
      ),
      CallGlassCircle(
        icon: call.screenSharing
            ? Icons.stop_screen_share_rounded
            : Icons.screen_share_rounded,
        label: tr(
          call.screenSharing
              ? 'call_control_stop'
              : _takingOver
              ? 'call_control_take_over'
              : 'call_control_screen_share',
        ),
        selected: call.screenSharing,
        diameter: m.controlDiameter,
        iconSize: m.controlIcon,
        labelFontSize: m.controlLabelFont,
        onPressed: _connected ? onToggleScreenShare : null,
      ),
      CallGlassCircle(
        icon: call.speaker ? Icons.volume_up_rounded : Icons.hearing_rounded,
        label: tr('call_control_speaker'),
        selected: call.speaker,
        diameter: m.controlDiameter,
        iconSize: m.controlIcon,
        labelFontSize: m.controlLabelFont,
        onPressed: _live ? onToggleSpeaker : null,
      ),
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: m.sideMargin),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < controls.length; i++) ...[
                if (i > 0) SizedBox(width: m.controlGap),
                Expanded(child: Center(child: controls[i])),
              ],
            ],
          ),
        ),
        SizedBox(height: m.design(28).clamp(12.0, 20.0)),
        CallGlassCircle(
          icon: Icons.call_end_rounded,
          label: hangLabel,
          diameter: m.hangupDiameter,
          iconSize: m.hangupIcon,
          labelFontSize: m.hangupLabelFont,
          background: const Color(0xFFE2554A),
          foreground: Colors.white,
          glow: true,
          onPressed: call.active ? onHangUp : null,
        ),
      ],
    );
  }
}

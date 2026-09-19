import 'package:flutter/material.dart';

import '../../../core/localization/app_translations.dart';
import '../providers/voice_call_state.dart';
import 'call_controls_anchor.dart';
import 'call_glass_circle.dart';
import 'call_overlay_metrics.dart';

/// Mute · Camera · Screen Share · Speaker, plus End.
///
/// Landscape: five seats in one **vertical** strip on the physical bottom
/// edge (anchor handles left/right). Portrait: four across, End drops under
/// with [AnimatedSize]. Circle seats never use [RotatedBox] — only glyphs
/// turn via [CallIconOrientation].
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
  final String? endLabel;

  bool get _live => call.active && call.phase != VoiceCallPhase.starting;
  bool get _connected => call.phase == VoiceCallPhase.connected;
  bool get _takingOver =>
      call.remoteScreenStream != null && !call.screenSharing;

  @override
  Widget build(BuildContext context) {
    final m = CallOverlayMetrics.of(context);
    final size = MediaQuery.sizeOf(context);
    final padding = MediaQuery.paddingOf(context);
    final landscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    String tr(String key) => AppTranslations.of(lang, key);
    final hangLabel = endLabel ?? tr('call_control_end');
    String? caption(String text) => landscape ? null : text;

    // Five seats must fit the short landscape edge without overflowing.
    final gap = landscape ? 8.0 : m.controlGap;
    final landscapeSeat = landscape
        ? ((size.height - padding.vertical - 24 - gap * 4) / 5).clamp(
            44.0,
            m.controlDiameter,
          )
        : m.controlDiameter;
    final seatD = landscape ? landscapeSeat : m.controlDiameter;
    final seatIcon = landscape ? seatD * 0.42 : m.controlIcon;
    final endDiameter = landscape ? seatD : m.hangupDiameter;
    final endIcon = landscape ? seatIcon : m.hangupIcon;

    Widget seat({
      required IconData icon,
      required String name,
      required bool selected,
      required VoidCallback? onPressed,
      Color? background,
      Color? foreground,
      bool glow = false,
      double? diameter,
      double? iconSize,
      Key? key,
    }) {
      return CallGlassCircle(
        key: key,
        icon: icon,
        label: caption(name),
        semanticLabel: name,
        selected: selected,
        diameter: diameter ?? seatD,
        iconSize: iconSize ?? seatIcon,
        labelFontSize: m.controlLabelFont,
        background: background,
        foreground: foreground,
        glow: glow,
        onPressed: onPressed,
      );
    }

    final toggles = <Widget>[
      seat(
        icon: call.muted ? Icons.mic_off_rounded : Icons.mic_rounded,
        name: tr(call.muted ? 'group_unmute' : 'group_mute'),
        selected: call.muted,
        onPressed: _live ? onToggleMute : null,
      ),
      seat(
        icon: call.cameraOn
            ? Icons.videocam_rounded
            : Icons.videocam_off_rounded,
        name: tr('chat_camera'),
        selected: call.cameraOn,
        onPressed: _connected ? onToggleCamera : null,
      ),
      seat(
        icon: call.screenSharing
            ? Icons.stop_screen_share_rounded
            : Icons.screen_share_rounded,
        name: tr(
          call.screenSharing
              ? 'call_control_stop'
              : _takingOver
              ? 'call_control_take_over'
              : 'call_control_screen_share',
        ),
        selected: call.screenSharing,
        onPressed: _connected ? onToggleScreenShare : null,
      ),
      seat(
        icon: call.speaker ? Icons.volume_up_rounded : Icons.hearing_rounded,
        name: tr('call_control_speaker'),
        selected: call.speaker,
        onPressed: _live ? onToggleSpeaker : null,
      ),
    ];

    final end = seat(
      key: const ValueKey('call-end'),
      icon: Icons.call_end_rounded,
      name: hangLabel,
      selected: false,
      diameter: endDiameter,
      iconSize: endIcon,
      background: const Color(0xFFE2554A),
      foreground: Colors.white,
      glow: !landscape,
      onPressed: call.active ? onHangUp : null,
    );

    return AnimatedSize(
      duration: callControlsOrientDuration,
      curve: Curves.easeOutCubic,
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      child: landscape
          ? Column(
              key: const ValueKey('deck-landscape'),
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < toggles.length; i++) ...[
                  if (i > 0) SizedBox(height: gap),
                  toggles[i],
                ],
                SizedBox(height: gap),
                end,
              ],
            )
          : Column(
              key: const ValueKey('deck-portrait'),
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < toggles.length; i++) ...[
                      if (i > 0) SizedBox(width: gap),
                      Expanded(child: Center(child: toggles[i])),
                    ],
                  ],
                ),
                SizedBox(height: m.design(28).clamp(12.0, 20.0)),
                end,
              ],
            ),
    );
  }
}

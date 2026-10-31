import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/localization/app_translations.dart';
import '../audio/call_audio_output.dart';
import '../group/call_icons.dart';
import '../providers/voice_call_state.dart';
import 'call_audio_dropdown.dart';
import 'call_audio_output_sheet.dart';
import 'call_controls_deck.dart';
import 'call_encrypted_label.dart';
import 'call_glass_circle.dart';
import 'call_overlay_metrics.dart';

/// The 1:1 call's controls.
///
/// Portrait: two rows of three — Camera · Screen Share · Audio output over
/// Minimize · End · Mute. Landscape: Mute · Camera · Screen Share · Audio
/// output · End in one strip, and minimize stays the chevron at the top.
///
/// The audio seat is the reference app's `CallAudioToggleButton`: earpiece ↔
/// speaker while those are the only outputs, a list (with a drop-down mark)
/// once a Bluetooth or wired headset joins them — see [pressCallAudioOutput].
///
/// Circle seats never use [RotatedBox] — only glyphs turn via
/// [CallIconOrientation]. The arrangement itself is [CallControlsDeck].
class CallControlsRow extends StatelessWidget {
  const CallControlsRow({
    super.key,
    required this.call,
    required this.onToggleMute,
    required this.onToggleCamera,
    required this.onToggleScreenShare,
    required this.onToggleSpeaker,
    required this.onHangUp,
    this.onMinimize,
    this.audio = CallAudioDevices.empty,
    this.lang = 'en',
    this.endLabel,
  });

  final VoiceCallState call;
  final VoidCallback onToggleMute;
  final VoidCallback onToggleCamera;
  final VoidCallback onToggleScreenShare;
  final VoidCallback onToggleSpeaker;
  final VoidCallback onHangUp;

  /// Leaves the call screen without hanging up. Portrait only: its seat is
  /// not in the landscape strip.
  final VoidCallback? onMinimize;
  final CallAudioDevices audio;
  final String lang;
  final String? endLabel;

  static const _maxLabelScale = 1.3;

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
    // Portrait: the deck, encrypted line included, stays inside the anchor's
    // edges and the lower 44% of the screen, clear of the caller's name.
    final scaler = MediaQuery.textScalerOf(
      context,
    ).clamp(maxScaleFactor: _maxLabelScale);
    final labelHeight = CallEncryptedLabel.heightFor(
      scaler.scale(m.controlLabelFont),
    );
    final portraitSeat = m.portraitSeat(
      width: size.width - 2 * math.max(8.0, padding.horizontal / 2),
      height: size.height * 0.44 - labelHeight - m.seatGap - m.deckLift,
      labelHeight: labelHeight,
    );
    final seatD = landscape ? landscapeSeat : portraitSeat;
    final seatIcon = seatD * 0.42;

    Widget seat({
      required CallGlyph icon,
      required String name,
      required bool selected,
      required VoidCallback? onPressed,
      Color? background,
      Color? foreground,
      bool glow = false,
      Key? key,
    }) {
      return CallGlassCircle(
        key: key,
        icon: icon,
        label: caption(name),
        semanticLabel: name,
        selected: selected,
        diameter: seatD,
        iconSize: seatIcon,
        labelFontSize: m.controlLabelFont,
        background: background,
        foreground: foreground,
        glow: glow,
        onPressed: onPressed,
      );
    }

    final face = CallAudioButtonFace.of(audio, speaker: call.speaker);
    final mute = seat(
      icon: call.muted ? CallIcons.micMuted : CallIcons.micOn,
      name: tr(call.muted ? 'group_unmute' : 'group_mute'),
      selected: call.muted,
      onPressed: _live ? onToggleMute : null,
    );
    final camera = seat(
      icon: call.cameraOn ? CallIcons.cameraOn : CallIcons.cameraOff,
      name: tr('chat_camera'),
      selected: call.cameraOn,
      onPressed: _connected ? onToggleCamera : null,
    );
    final share = seat(
      icon: call.screenSharing
          ? CallIcons.screenShareStop
          : CallIcons.screenShare,
      name: tr(
        call.screenSharing
            ? 'call_control_stop'
            : _takingOver
            ? 'call_control_take_over'
            : 'call_control_screen_share',
      ),
      selected: call.screenSharing,
      onPressed: _connected ? onToggleScreenShare : null,
    );
    final speaker = CallAudioDropdown(
      show: face.dropdown,
      diameter: seatD,
      child: seat(
        icon: callAudioOutputIcon(face.output),
        name: callAudioShortLabel(face.output, lang),
        selected: face.selected,
        onPressed: _live ? onToggleSpeaker : null,
      ),
    );

    final end = seat(
      key: const ValueKey('call-end'),
      icon: CallIcons.leave,
      name: hangLabel,
      selected: false,
      background: const Color(0xFFE2554A),
      foreground: Colors.white,
      glow: !landscape,
      onPressed: call.active ? onHangUp : null,
    );
    final minimize = seat(
      key: const ValueKey('call-minimize'),
      icon: CallIcons.minimize,
      name: tr('call_control_minimize'),
      selected: false,
      onPressed: onMinimize,
    );

    // Past [_maxLabelScale] a two-word caption wraps under its seat.
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: _maxLabelScale,
      child: CallControlsDeck(
        landscape: landscape,
        gap: gap,
        rowGap: m.seatGap,
        seatGap: m.seatGap,
        seatWidth: seatD,
        header: CallEncryptedLabel(
          lines: [tr('call_end_to_end_encrypted'), tr('call_never_recorded')],
          fontSize: m.controlLabelFont,
        ),
        strip: [mute, camera, share, speaker, end],
        top: [camera, share, speaker],
        bottom: [minimize, end, mute],
      ),
    );
  }
}

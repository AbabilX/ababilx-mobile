import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/localization/app_translations.dart';
import '../call_status_text.dart';
import '../providers/voice_call_state.dart';
import 'call_chrome_auto_hide.dart';
import 'call_controls_anchor.dart';
import 'call_minimize_button.dart';
import 'call_network_badge.dart';
import 'call_note.dart';
import 'call_overlay_metrics.dart';
import 'call_peer_identity.dart';
import 'call_top_notice.dart';
import 'call_video_view.dart';
import 'call_wallpaper.dart';
import 'local_camera_preview.dart';
import 'remote_screen_view.dart';

/// Outgoing / connected / ended 1:1 call surface.
///
/// Audio-only: theme wallpaper + glass overlay. Remote video or screen share
/// replaces the wallpaper full-bleed; controls stay as an overlay that
/// auto-hides after idle so the stage is clear — tap the stage to reveal.
class ConnectedCallBody extends StatelessWidget {
  const ConnectedCallBody({
    super.key,
    required this.call,
    required this.onMinimize,
    required this.onSwitchCamera,
    required this.controls,
    this.lang = 'en',
  });

  final VoiceCallState call;
  final VoidCallback onMinimize;
  final VoidCallback onSwitchCamera;
  final Widget controls;
  final String lang;

  bool get _sharing => call.remoteScreenStream != null;

  bool get _remoteVideo => call.remoteCameraStream != null;

  bool get _stage => _sharing || _remoteVideo;

  bool get _topBusy => _stage || call.screenSharing;

  bool get _live => call.phase == VoiceCallPhase.connected;

  /// Not answered yet: only this phone's own link can be measured.
  bool get _ringing =>
      call.phase == VoiceCallPhase.starting ||
      call.phase == VoiceCallPhase.outgoingRinging ||
      call.phase == VoiceCallPhase.connecting;

  @override
  Widget build(BuildContext context) {
    final m = CallOverlayMetrics.of(context);
    final padding = MediaQuery.paddingOf(context);
    final ended =
        call.phase == VoiceCallPhase.ended ||
        call.phase == VoiceCallPhase.failed ||
        call.phase == VoiceCallPhase.idle;
    final showWave =
        call.phase == VoiceCallPhase.outgoingRinging ||
        call.phase == VoiceCallPhase.starting;
    final identityTop = CallOverlayMetrics.clampTop(
      m.avatarTop,
      min: padding.top + 48,
      max: m.size.height * 0.42,
    );
    // Watch mode: fade chrome so remote video / screen is unobstructed.
    final autoHideChrome = _stage && !ended;
    // Portrait carries minimize as a seat in the control deck; the chevron is
    // for landscape, whose strip has no room for it, and for the ended screen.
    final chevron =
        ended || MediaQuery.orientationOf(context) == Orientation.landscape;

    return Stack(
      fit: StackFit.expand,
      children: [
        if (_sharing)
          RemoteScreenView(stream: call.remoteScreenStream!)
        else if (_remoteVideo)
          CallVideoView(stream: call.remoteCameraStream!)
        else
          const CallWallpaper(),
        CallChromeAutoHide(
          enabled: autoHideChrome,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (chevron)
                Positioned(
                  top: padding.top + 8,
                  left: math.max(padding.left, 12),
                  child: CallMinimizeButton(onPressed: onMinimize),
                ),
              if (!_stage)
                Positioned(
                  top: identityTop,
                  left: 0,
                  right: 0,
                  child: CallPeerIdentity(
                    name: call.peerName,
                    avatarUrl: call.peerAvatar,
                    status: voiceCallStatusText(call, lang: lang),
                    showWave: showWave,
                  ),
                ),
              if (_topBusy)
                Positioned(
                  top: padding.top + 8,
                  left: 56,
                  right: 56,
                  child: CallTopNotice(
                    name: call.peerName,
                    status: voiceCallStatusText(call, lang: lang),
                    showPeer: _stage,
                    sharingText: call.screenSharing
                        ? AppTranslations.of(lang, 'call_sharing_own_screen')
                        : null,
                  ),
                ),
              if (_ringing || (_live && !call.reconnecting))
                Positioned(
                  // Under the name line while video or a screen fills the top.
                  top: padding.top + (_topBusy ? 60 : 14),
                  left: _topBusy ? math.max(padding.left, 12) + 4 : null,
                  right: _topBusy ? null : math.max(padding.right, 12) + 4,
                  child: CallNetworkBadge(lang: lang, ownLink: _ringing),
                ),
              if (call.error != null)
                Positioned(
                  top: m.size.height * 0.55,
                  left: 24,
                  right: 24,
                  child: CallNote(text: call.error!, error: true),
                ),
              if (call.screenShareError != null)
                Positioned(
                  top: m.size.height * 0.58,
                  left: 24,
                  right: 24,
                  child: CallNote(text: call.screenShareError!, error: true),
                ),
              if (call.cameraError != null)
                Positioned(
                  top: m.size.height * 0.61,
                  left: 24,
                  right: 24,
                  child: CallNote(text: call.cameraError!, error: true),
                ),
              if (!ended) CallControlsAnchor(child: controls),
            ],
          ),
        ),
        // PiP stays above chrome so self-view remains after controls fade.
        if (call.localCameraStream != null)
          Positioned(
            right: math.max(padding.right, 12) + 4,
            top: padding.top + 48,
            child: LocalCameraPreview(
              stream: call.localCameraStream!,
              mirror: call.cameraFront,
              onSwitchCamera: onSwitchCamera,
            ),
          ),
        if (ended)
          Positioned(
            left: math.max(padding.left, 12),
            right: math.max(padding.right, 12),
            bottom: math.max(padding.bottom, 12),
            child: Center(
              child: SizedBox(
                width: m.doneButtonWidth,
                height: m.doneButtonHeight,
                child: FilledButton.tonal(
                  onPressed: onMinimize,
                  style: FilledButton.styleFrom(
                    shape: const StadiumBorder(),
                    padding: EdgeInsets.zero,
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.black.withValues(alpha: 0.28),
                    textStyle: TextStyle(
                      fontSize: m.doneButtonFont,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: Text(AppTranslations.of(lang, 'call_done')),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

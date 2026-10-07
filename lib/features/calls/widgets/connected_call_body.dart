import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/localization/app_translations.dart';
import '../call_status_text.dart';
import '../providers/voice_call_state.dart';
import 'call_chrome_auto_hide.dart';
import 'call_controls_anchor.dart';
import 'call_minimize_button.dart';
import 'call_overlay_metrics.dart';
import 'call_peer_identity.dart';
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
              if (_stage)
                Positioned(
                  top: padding.top + 8,
                  left: 56,
                  right: 56,
                  child: Column(
                    children: [
                      Text(
                        call.peerName,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: m.nameFont * 0.78,
                          fontWeight: FontWeight.w600,
                          shadows: const [
                            Shadow(color: Color(0x66000000), blurRadius: 6),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        voiceCallStatusText(call, lang: lang),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.75),
                          fontSize: m.statusFont,
                          shadows: const [
                            Shadow(color: Color(0x66000000), blurRadius: 6),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              if (call.error != null)
                Positioned(
                  top: m.size.height * 0.55,
                  left: 24,
                  right: 24,
                  child: _Note(text: call.error!, error: true),
                ),
              if (call.screenSharing)
                Positioned(
                  top: m.size.height * 0.55,
                  left: 24,
                  right: 24,
                  child: _Note(
                    text: AppTranslations.of(lang, 'call_sharing_own_screen'),
                  ),
                ),
              if (call.screenShareError != null)
                Positioned(
                  top: m.size.height * 0.58,
                  left: 24,
                  right: 24,
                  child: _Note(text: call.screenShareError!, error: true),
                ),
              if (call.cameraError != null)
                Positioned(
                  top: m.size.height * 0.61,
                  left: 24,
                  right: 24,
                  child: _Note(text: call.cameraError!, error: true),
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

class _Note extends StatelessWidget {
  const _Note({required this.text, this.error = false});

  final String text;
  final bool error;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: error ? const Color(0xFFFF8A80) : Colors.white,
          ),
        ),
      ),
    );
  }
}

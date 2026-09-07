import 'package:flutter/material.dart';

import '../../../shared/widgets/app_avatar.dart';
import '../call_status_text.dart';
import '../providers/voice_call_state.dart';
import 'call_backdrop.dart';
import 'call_top_bar.dart';
import 'call_video_view.dart';
import 'local_camera_preview.dart';
import 'remote_screen_view.dart';

/// Everything a call shows once it is no longer ringing.
///
/// Signal's connected screen is the same picture as the ringing one with the
/// scrim eased off (0.2 rather than 0.4) — the eye stays on the same subject
/// through answering, instead of the screen changing identity. When a screen
/// share arrives the shared surface takes the window and the person shrinks
/// into the top bar, because at that point the screen is the subject. The
/// peer's camera does the same — it *is* the person — and our own camera
/// sits in a corner thumbnail with the flip button on it.
class ConnectedCallBody extends StatelessWidget {
  const ConnectedCallBody({
    super.key,
    required this.call,
    required this.onMinimize,
    required this.onSwitchCamera,
    required this.controls,
  });

  final VoiceCallState call;
  final VoidCallback onMinimize;
  final VoidCallback onSwitchCamera;
  final Widget controls;

  bool get _sharing => call.remoteScreenStream != null;

  bool get _remoteVideo => call.remoteCameraStream != null;

  /// Something full-screen has replaced the avatar-and-name layout.
  bool get _stage => _sharing || _remoteVideo;

  @override
  Widget build(BuildContext context) {
    final ended =
        call.phase == VoiceCallPhase.ended ||
        call.phase == VoiceCallPhase.failed ||
        call.phase == VoiceCallPhase.idle;

    return Stack(
      fit: StackFit.expand,
      children: [
        // A shared screen wins over the camera: someone sharing is asking
        // you to look at it.
        if (_sharing)
          RemoteScreenView(stream: call.remoteScreenStream!)
        else if (_remoteVideo)
          CallVideoView(stream: call.remoteCameraStream!)
        else
          CallBackdrop(avatarUrl: call.peerAvatar, scrim: 0.35),
        if (call.localCameraStream != null)
          Positioned(
            right: 16,
            top: MediaQuery.paddingOf(context).top + 64,
            child: LocalCameraPreview(
              stream: call.localCameraStream!,
              mirror: call.cameraFront,
              onSwitchCamera: onSwitchCamera,
            ),
          ),
        SafeArea(
          child: Column(
            children: [
              if (_stage) const SizedBox.shrink() else const Spacer(flex: 2),
              if (!_stage) ...[
                AppAvatar(
                  size: 112,
                  url: call.peerAvatar,
                  name: call.peerName,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.35),
                    width: 2,
                  ),
                ),
                const SizedBox(height: 20),
                _Name(name: call.peerName),
                const SizedBox(height: 10),
                _Status(call: call),
              ],
              if (call.error != null) _Note(text: call.error!, error: true),
              if (call.screenSharing)
                const _Note(text: 'You are sharing your screen'),
              if (call.screenShareError != null)
                _Note(text: call.screenShareError!, error: true),
              if (call.cameraError != null)
                _Note(text: call.cameraError!, error: true),
              const Spacer(flex: 3),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                child: ended
                    ? FilledButton.tonal(
                        onPressed: onMinimize,
                        child: const Text('Done'),
                      )
                    : controls,
              ),
            ],
          ),
        ),
        CallTopBar(
          onMinimize: onMinimize,
          title: _stage ? call.peerName : null,
          subtitle: _stage ? voiceCallStatusText(call) : null,
        ),
      ],
    );
  }
}

class _Name extends StatelessWidget {
  const _Name({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Text(
        name,
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          shadows: callTextShadow,
        ),
      ),
    );
  }
}

class _Status extends StatelessWidget {
  const _Status({required this.call});

  final VoiceCallState call;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final connected = call.phase == VoiceCallPhase.connected;
    return Text(
      voiceCallStatusText(call),
      textAlign: TextAlign.center,
      style: connected
          ? textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w500,
              letterSpacing: 1.1,
              fontFeatures: const [FontFeature.tabularFigures()],
              shadows: callTextShadow,
            )
          : textTheme.titleMedium?.copyWith(
              color: call.phase == VoiceCallPhase.failed
                  ? const Color(0xFFFF8A80)
                  : Colors.white70,
              shadows: callTextShadow,
            ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.text, this.error = false});

  final String text;
  final bool error;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: error ? const Color(0xFFFF8A80) : Colors.white,
          shadows: callTextShadow,
        ),
      ),
    );
  }
}

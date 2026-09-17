import 'package:flutter/material.dart';

import '../../../shared/widgets/app_avatar.dart';
import '../../../core/localization/app_translations.dart';
import '../call_status_text.dart';
import '../providers/voice_call_state.dart';
import 'call_backdrop.dart';
import 'call_top_bar.dart';
import 'call_video_view.dart';
import 'local_camera_preview.dart';
import 'remote_screen_view.dart';

/// Everything a call shows once it is no longer ringing.
///
/// Controls sit directly on the call surface. Remote screen sharing takes
/// priority over remote video; the local camera stays in a corner preview.
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

  /// Passed down rather than read from a provider: this widget and the two
  /// below it are plain StatelessWidgets, and the status line they draw is
  /// the same pure function the return bar and the PiP window read.
  final String lang;

  bool get _sharing => call.remoteScreenStream != null;

  bool get _remoteVideo => call.remoteCameraStream != null;

  /// Something full-screen has replaced the avatar-and-name layout.
  bool get _stage => _sharing || _remoteVideo;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
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
          CallBackdrop(avatarUrl: call.peerAvatar, themeAware: true),
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
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Padding(
                  // A 12dp gutter, not 16: the control deck is the screen's
                  // widest element and Expressive wants it near the edges.
                  padding: const EdgeInsets.fromLTRB(12, 68, 12, 16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!_stage)
                            Padding(
                              padding: EdgeInsets.only(
                                top: constraints.maxHeight > 650 ? 72 : 24,
                                bottom: 24,
                              ),
                              child: AppAvatar(
                                size: constraints.maxHeight < 650 ? 112 : 176,
                                url: call.peerAvatar,
                                name: call.peerName,
                                border: Border.all(
                                  color: colors.outlineVariant,
                                  width: 2,
                                ),
                              ),
                            ),
                          if (call.error != null)
                            _Note(text: call.error!, error: true),
                          if (call.screenSharing)
                            _Note(
                              text: AppTranslations.of(
                                lang,
                                'call_sharing_own_screen',
                              ),
                            ),
                          if (call.screenShareError != null)
                            _Note(text: call.screenShareError!, error: true),
                          if (call.cameraError != null)
                            _Note(text: call.cameraError!, error: true),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 28),
                        // Done takes the deck's own footprint, so the screen
                        // does not collapse to a small centred button the
                        // moment the call ends.
                        child: ended
                            ? SizedBox(
                                width: double.infinity,
                                height: 76,
                                child: FilledButton.tonal(
                                  onPressed: onMinimize,
                                  style: FilledButton.styleFrom(
                                    shape: const StadiumBorder(),
                                  ),
                                  child: Text(
                                    AppTranslations.of(lang, 'call_done'),
                                  ),
                                ),
                              )
                            : controls,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        CallTopBar(
          themeAware: true,
          onMinimize: onMinimize,
          centerTitle: true,
          title: call.peerName,
          subtitle: voiceCallStatusText(call, lang: lang),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: error
                  ? Theme.of(context).colorScheme.error
                  : Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}

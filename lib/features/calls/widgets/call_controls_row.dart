import 'package:flutter/material.dart';

import '../../../core/localization/app_translations.dart';
import '../providers/voice_call_state.dart';
import 'call_control_button.dart';

/// Two paired rows and a centered End control, stable throughout the call.
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
    Widget pair(Widget left, Widget right) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: left),
        Expanded(child: right),
      ],
    );
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              pair(
                CallControlButton(
                  themeAware: true,
                  size: 64,
                  icon: call.muted ? Icons.mic_off_rounded : Icons.mic_rounded,
                  label: tr(call.muted ? 'group_unmute' : 'group_mute'),
                  selected: call.muted,
                  onPressed: _live ? onToggleMute : null,
                ),
                CallControlButton(
                  themeAware: true,
                  size: 64,
                  icon: call.cameraOn
                      ? Icons.videocam_rounded
                      : Icons.videocam_off_rounded,
                  label: tr('chat_camera'),
                  selected: call.cameraOn,
                  onPressed: _connected ? onToggleCamera : null,
                ),
              ),
              const SizedBox(height: 20),
              pair(
                CallControlButton(
                  themeAware: true,
                  size: 64,
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
                CallControlButton(
                  themeAware: true,
                  size: 64,
                  icon: call.speaker
                      ? Icons.volume_up_rounded
                      : Icons.hearing_rounded,
                  label: tr('call_control_speaker'),
                  selected: call.speaker,
                  onPressed: _live ? onToggleSpeaker : null,
                ),
              ),
              const SizedBox(height: 20),
              CallControlButton(
                themeAware: true,
                size: 64,
                icon: Icons.call_end_rounded,
                label: tr('call_control_end'),
                background: colors.error,
                foreground: colors.onError,
                onPressed: call.active ? onHangUp : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

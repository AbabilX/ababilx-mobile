import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../shared/widgets/app_toast.dart';
import '../../messages/chat-timeline/composer_input_bar_buttons.dart';
import '../../messages/chat-timeline/voice_message_recorder.dart';
import '../engine/protocol/share_envelope.dart';
import '../local_share_actions.dart';
import '../local_share_engine.dart';
import '../share_text.dart';
import '../sheets/attach_sheet.dart';
import 'share_recording_bar.dart';

/// The thread's composer, shaped like the chat one: a pill with the text and
/// the attach button, and one accent circle that is the microphone until
/// there is something to send.
class ShareComposer extends ConsumerStatefulWidget {
  const ShareComposer({super.key, required this.engine, required this.peerId});

  final LocalShareEngine engine;
  final String peerId;

  @override
  ConsumerState<ShareComposer> createState() => _ShareComposerState();
}

class _ShareComposerState extends ConsumerState<ShareComposer> {
  final _text = TextEditingController();
  final _recorder = VoiceMessageRecorder();
  bool _recording = false;
  bool _hasText = false;

  @override
  void dispose() {
    if (_recording) unawaited(_recorder.cancel());
    _text.dispose();
    super.dispose();
  }

  void _sendText() {
    final text = _text.text.trim();
    if (text.isEmpty) return;
    _text.clear();
    setState(() => _hasText = false);
    unawaited(widget.engine.sendText(widget.peerId, text));
  }

  Future<void> _attach() async {
    final picked = await showShareAttachSheet(context);
    if (picked == null || picked.picks.isEmpty) return;
    unawaited(
      widget.engine.sendFiles(
        widget.peerId,
        picked.picks,
        kind: picked.folderName == null ? ShareKind.files : ShareKind.folder,
        folderName: picked.folderName,
      ),
    );
  }

  Future<void> _startRecording() async {
    try {
      await _recorder.start();
      if (mounted) setState(() => _recording = true);
    } on MicrophonePermissionException {
      _toast('ls_mic_denied');
    } catch (_) {
      _toast('ls_record_failed');
    }
  }

  void _toast(String key) {
    if (mounted) showAppToast(context, lsText(ref, key), isError: true);
  }

  Future<void> _stopRecording({required bool send}) async {
    setState(() => _recording = false);
    if (!send) return _recorder.cancel();
    final voice = await _recorder.stop();
    if (voice == null) return;
    unawaited(
      widget.engine.sendFiles(widget.peerId, [
        SharePick(
          path: voice.path,
          name: voice.fileName,
          mime: 'audio/mp4',
          owned: true,
          durationMs: voice.duration.inMilliseconds,
        ),
      ], kind: ShareKind.voice),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
          child: _recording
              ? ShareRecordingBar(
                  onCancel: () => _stopRecording(send: false),
                  onSend: () => _stopRecording(send: true),
                  cancelLabel: lsText(ref, 'ls_discard'),
                  sendLabel: lsText(ref, 'ls_send'),
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(child: _pill(colors)),
                    const SizedBox(width: 8),
                    AccentCircle(
                      sending: false,
                      // The chat composer's rule: + until there is a draft,
                      // the send arrow after.
                      label: lsText(ref, _hasText ? 'ls_send' : 'ls_attach'),
                      icon: _hasText
                          ? HugeIcons.strokeRoundedSent
                          : HugeIcons.strokeRoundedAdd01,
                      rotated: false,
                      onTap: _hasText ? _sendText : () => unawaited(_attach()),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _pill(ColorScheme colors) {
    return Container(
      constraints: const BoxConstraints(minHeight: 48),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(26),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const SizedBox(width: 16),
          Expanded(
            child: TextField(
              controller: _text,
              minLines: 1,
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (value) {
                final has = value.trim().isNotEmpty;
                if (has != _hasText) setState(() => _hasText = has);
              },
              style: const TextStyle(fontSize: 16, height: 1.3),
              decoration: InputDecoration(
                hintText: lsText(ref, 'ls_message_hint'),
                hintStyle: TextStyle(
                  fontSize: 16,
                  color: colors.onSurfaceVariant,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.fromLTRB(0, 14, 0, 14),
              ),
            ),
          ),
          // The mic lives in the field and steps aside for a draft.
          if (!_hasText)
            PillIcon(
              icon: HugeIcons.strokeRoundedMic01,
              tooltip: lsText(ref, 'ls_voice'),
              onTap: _startRecording,
            ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}

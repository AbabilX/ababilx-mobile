import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/localization/app_translations.dart';
import '../data/models/chat_models.dart';
import '../providers/chat_provider.dart';
import '../tiptap_plain_text.dart';
import 'composer_attach.dart';
import 'composer_collapsed.dart';
import 'composer_expanded_shell.dart';
import 'composer_recording_bar.dart';
import 'composer_slack_field.dart';
import 'composer_text_actions.dart';
import 'composer_toolbar.dart';
import 'voice_message_recorder.dart';

class MessageComposer extends ConsumerStatefulWidget {
  const MessageComposer({
    super.key,
    required this.conversationId,
    this.parentId,
    this.hintName = 'someone',
    this.initialText = '',
  });

  final String conversationId;
  final String? parentId;
  final String hintName;
  final String initialText;

  @override
  ConsumerState<MessageComposer> createState() => _MessageComposerState();
}

class _MessageComposerState extends ConsumerState<MessageComposer> {
  late final TextEditingController _ctrl;
  late final FocusNode _focus;
  final _voiceRecorder = VoiceMessageRecorder();
  final _recordStopwatch = Stopwatch();
  final _pending = <ChatAttachmentInput>[];
  Timer? _recordClock;
  Duration _recordElapsed = Duration.zero;
  bool _focused = false;
  bool _forceExpanded = false;
  bool _tall = false;
  bool _recording = false;
  bool _recordPreparing = false;
  bool _recordFinishing = false;
  bool _releaseRequested = false;
  bool _uploadingVoice = false;
  bool _holdingMic = false;

  String get _hint => 'Message ${widget.hintName}';
  bool get _hasDraft => _ctrl.text.trim().isNotEmpty || _pending.isNotEmpty;
  bool get _expanded => _forceExpanded || _focused || _hasDraft;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialText)
      ..addListener(() => setState(() {}));
    _focus = FocusNode()..addListener(_onFocus);
  }

  void _onFocus() {
    setState(() {
      _focused = _focus.hasFocus;
      if (!_focus.hasFocus && !_hasDraft) {
        _forceExpanded = false;
        _tall = false;
      }
    });
  }

  void _openExpanded() {
    setState(() => _forceExpanded = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _recordClock?.cancel();
    unawaited(_voiceRecorder.dispose());
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final plain = _ctrl.text.trim();
    if (plain.isEmpty && _pending.isEmpty) return;
    await ref
        .read(chatProvider.notifier)
        .sendMessage(
          body: plain.isEmpty ? '' : textToTiptapJson(plain),
          attachments: List.of(_pending),
          parentId: widget.parentId,
        );
    if (!mounted) return;
    _ctrl.clear();
    setState(() {
      _pending.clear();
      _forceExpanded = false;
      _tall = false;
    });
    _focus.unfocus();
  }

  Future<void> _attach({ImageSource? source}) => pickAndUploadImage(
    context,
    ref,
    conversationId: widget.conversationId,
    source: source,
    onAdded: (a) {
      if (!mounted) return;
      setState(() {
        _pending.add(a);
        _forceExpanded = true;
      });
      _focus.requestFocus();
    },
  );

  Future<void> _startVoiceRecording() async {
    if (_recording || _uploadingVoice || ref.read(chatProvider).sending) return;
    _focus.unfocus();
    setState(() {
      _recording = true;
      _recordPreparing = true;
      _releaseRequested = false;
      _recordElapsed = Duration.zero;
    });
    try {
      await _voiceRecorder.start();
      if (!mounted) {
        await _voiceRecorder.cancel();
        return;
      }
      setState(() => _recordPreparing = false);
      _recordStopwatch
        ..reset()
        ..start();
      _recordClock?.cancel();
      _recordClock = Timer.periodic(const Duration(milliseconds: 200), (_) {
        if (mounted) {
          setState(() => _recordElapsed = _recordStopwatch.elapsed);
          if (_recordElapsed >= const Duration(seconds: 60)) {
            unawaited(_finishVoiceRecording());
          }
        }
      });
      if (_releaseRequested || !_holdingMic) await _finishVoiceRecording();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _recording = false;
        _recordPreparing = false;
      });
      _showMessage(
        'Microphone permission is required to record.',
        'রেকর্ড করতে মাইক্রোফোনের অনুমতি প্রয়োজন।',
      );
    }
  }

  void _releaseVoiceRecording() {
    _holdingMic = false;
    if (!_recording || _recordFinishing) return;
    if (_recordPreparing) {
      _releaseRequested = true;
      return;
    }
    unawaited(_finishVoiceRecording());
  }

  Future<void> _finishVoiceRecording() async {
    if (_recordFinishing) return;
    final notifier = ref.read(chatProvider.notifier);
    _recordFinishing = true;
    _recordStopwatch.stop();
    _recordClock?.cancel();
    RecordedVoiceMessage? recording;
    try {
      recording = await _voiceRecorder.stop();
      if (recording == null ||
          recording.sizeBytes == 0 ||
          recording.duration < const Duration(milliseconds: 700)) {
        if (recording != null) await _voiceRecorder.delete(recording);
        if (mounted) {
          setState(() {
            _recording = false;
            _recordPreparing = false;
          });
          _showMessage(
            'Hold a little longer to record.',
            'রেকর্ড করতে একটু বেশি সময় ধরে রাখুন।',
          );
        }
        return;
      }

      if (mounted) {
        setState(() {
          _recording = false;
          _recordPreparing = false;
          _uploadingVoice = true;
        });
      }

      final bytes = await File(recording.path).readAsBytes();
      final presign = await notifier.presignAttachment(
        widget.conversationId,
        contentType: RecordedVoiceMessage.contentType,
        fileName: recording.fileName,
        sizeBytes: bytes.length,
      );
      try {
        await notifier.uploadAttachmentBytes(
          presign,
          bytes,
          RecordedVoiceMessage.contentType,
        );
        await notifier.sendMessage(
          conversationId: widget.conversationId,
          body: '',
          parentId: widget.parentId,
          attachments: [
            ChatAttachmentInput(
              fileUrl: presign.publicUrl,
              fileName: recording.fileName,
              contentType: RecordedVoiceMessage.contentType,
              sizeBytes: bytes.length,
            ),
          ],
        );
      } catch (_) {
        await notifier.discardUpload(widget.conversationId, presign.publicUrl);
        rethrow;
      }
    } catch (_) {
      if (mounted) {
        _showMessage(
          'Could not send the voice message.',
          'ভয়েস মেসেজ পাঠানো যায়নি।',
        );
      }
    } finally {
      if (recording != null) await _voiceRecorder.delete(recording);
      _recordFinishing = false;
      if (mounted) {
        setState(() {
          _recording = false;
          _recordPreparing = false;
          _uploadingVoice = false;
          _recordElapsed = Duration.zero;
        });
      }
      _recordStopwatch.reset();
    }
  }

  void _showMessage(String english, String bangla) {
    if (!mounted) return;
    final language = ref.read(appLanguageProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(language == 'bn' ? bangla : english)),
    );
  }

  void _pressMic() {
    _holdingMic = true;
    unawaited(_startVoiceRecording());
  }

  @override
  Widget build(BuildContext context) {
    final sending = ref.watch(chatProvider).sending;
    String tr(String key) => AppTranslations.translate(context, ref, key);
    late final Widget composer;
    if (_recording || _uploadingVoice) {
      composer = ComposerRecordingBar(
        elapsed: _recordElapsed,
        preparing: _recordPreparing,
        uploading: _uploadingVoice,
        releaseLabel: tr('chat_release_to_send'),
        preparingLabel: tr('chat_recording_starting'),
        sendingLabel: tr('chat_voice_sending'),
      );
    } else if (!_expanded) {
      composer = ComposerCollapsed(
        hint: _hint,
        onFocusTap: _openExpanded,
        onPlus: () => _attach(),
        onMicDown: _pressMic,
        voiceTooltip: tr('chat_hold_to_record'),
      );
    } else {
      composer = ComposerExpandedShell(
        pending: _pending,
        onRemove: (i) => setState(() => _pending.removeAt(i)),
        onAddPhoto: () => _attach(),
        field: ComposerSlackField(
          controller: _ctrl,
          focusNode: _focus,
          hint: _hint,
          sending: sending,
          canSend: _hasDraft,
          expanded: _tall,
          onAttach: () => _attach(source: ImageSource.gallery),
          onFormat: () => wrapComposerBold(_ctrl),
          onEmoji: () => showEmojiPicker(
            context,
            (emoji) => insertComposerEmoji(_ctrl, emoji),
          ),
          onMention: () => insertComposerAt(_ctrl),
          onExpand: () => setState(() => _tall = !_tall),
          onSend: _send,
          attachTooltip: tr('chat_attach'),
          formatTooltip: tr('chat_format'),
          emojiTooltip: tr('chat_emoji'),
          mentionTooltip: tr('chat_mention'),
          expandTooltip: tr('chat_expand'),
          sendTooltip: tr('chat_send'),
        ),
      );
    }
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerUp: (_) => _releaseVoiceRecording(),
      onPointerCancel: (_) => _releaseVoiceRecording(),
      child: composer,
    );
  }
}

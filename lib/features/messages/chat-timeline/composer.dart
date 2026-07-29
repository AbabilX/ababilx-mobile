import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/localization/app_translations.dart';
import '../data/models/chat_models.dart';
import '../providers/chat_provider.dart';
import '../tiptap_plain_text.dart';
import 'composer_attach.dart';
import 'composer_collapsed.dart';
import 'composer_expanded_shell.dart';
import 'composer_recording_bar.dart';
import 'composer_reply_banner.dart';
import 'composer_share_contact.dart';
import 'composer_slack_field.dart';
import 'composer_text_actions.dart';
import 'voice_message_recorder.dart';

class MessageComposer extends ConsumerStatefulWidget {
  const MessageComposer({
    super.key,
    required this.conversationId,
    this.parentId,
    this.hintName = 'someone',
    this.initialText = '',
    this.isGroup = false,
  });

  final String conversationId;
  final String? parentId;
  final String hintName;
  final String initialText;

  /// Channel/group — show @ mention beside share-contact.
  final bool isGroup;

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
  bool _uploadingVoice = false;
  bool _paused = false;
  bool _viewOnce = false;

  String get _hint => 'Message ${widget.hintName}';
  bool get _hasDraft => _ctrl.text.trim().isNotEmpty || _pending.isNotEmpty;
  bool get _expanded =>
      _forceExpanded ||
      _focused ||
      _hasDraft ||
      ref.watch(chatProvider).replyToMessage != null;
  bool get _voiceSheetOpen => _recording || _recordPreparing || _uploadingVoice;

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
    final replyTarget = ref.read(chatProvider).replyToMessage;
    final effectiveParentId = replyTarget?.id ?? widget.parentId;
    // Clear the composer immediately — the message is already in the feed
    // as a pending bubble (optimistic UI). No need to await.
    ref.read(chatProvider.notifier).setReplyToMessage(null);
    final body = plain.isEmpty ? '' : textToTiptapJson(plain);
    final attachments = List<ChatAttachmentInput>.of(_pending);
    if (!mounted) return;
    _ctrl.clear();
    setState(() {
      _pending.clear();
      _forceExpanded = false;
      _tall = false;
    });
    _focus.unfocus();
    // Fire-and-forget — result (success/fail) reflected in the bubble icon.
    unawaited(ref
        .read(chatProvider.notifier)
        .sendMessage(
          body: body,
          attachments: attachments,
          parentId: effectiveParentId,
        ));
  }


  Future<void> _attach({ImageSource? source}) async {
    if (!mounted) return;
    try {
      await pickAndUploadAttachment(
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
    } catch (_) {
      if (!mounted) return;
      _showMessage('Could not attach this file.', 'ফাইল সংযুক্ত করা যায়নি।');
    }
  }

  Future<void> _startVoiceRecording() async {
    if (_voiceSheetOpen || _recordFinishing || ref.read(chatProvider).sending) {
      return;
    }
    _focus.unfocus();
    setState(() {
      _recordPreparing = true;
      _paused = false;
      _recordElapsed = Duration.zero;
    });
    try {
      await _voiceRecorder.start();
      if (!mounted) {
        await _voiceRecorder.cancel();
        return;
      }
      setState(() {
        _recording = true;
        _recordPreparing = false;
      });
      _recordStopwatch
        ..reset()
        ..start();
      _recordClock?.cancel();
      _recordClock = Timer.periodic(const Duration(milliseconds: 200), (_) {
        if (!mounted || _paused) return;
        setState(() => _recordElapsed = _recordStopwatch.elapsed);
        if (_recordElapsed >= const Duration(seconds: 60)) {
          unawaited(_finishVoiceRecording());
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _recording = false;
        _recordPreparing = false;
        _paused = false;
      });
      if (error is MicrophonePermissionException && error.permanentlyDenied) {
        _showMicPermissionSettings();
        return;
      }
      _showMessage(
        'Microphone permission is required to record.',
        'রেকর্ড করতে মাইক্রোফোনের অনুমতি প্রয়োজন।',
      );
    }
  }

  Future<void> _cancelVoiceRecording() async {
    if (_recordFinishing || _uploadingVoice) return;
    _recordClock?.cancel();
    _recordStopwatch
      ..stop()
      ..reset();
    await _voiceRecorder.cancel();
    if (!mounted) return;
    setState(() {
      _recording = false;
      _recordPreparing = false;
      _paused = false;
      _recordElapsed = Duration.zero;
    });
  }

  Future<void> _togglePause() async {
    if (!_recording || _recordFinishing || _uploadingVoice) return;
    if (_paused) {
      await _voiceRecorder.resume();
      if (!mounted) return;
      _recordStopwatch.start();
      setState(() => _paused = false);
    } else {
      await _voiceRecorder.pause();
      if (!mounted) return;
      _recordStopwatch.stop();
      setState(() {
        _paused = true;
        _recordElapsed = _recordStopwatch.elapsed;
      });
    }
  }

  Future<void> _finishVoiceRecording() async {
    if (_recordFinishing || !_recording) return;
    final notifier = ref.read(chatProvider.notifier);
    _recordFinishing = true;
    _recordStopwatch.stop();
    _recordClock?.cancel();
    RecordedVoiceMessage? recording;
    try {
      recording = await _voiceRecorder.stop();
      if (recording == null ||
          recording.sizeBytes == 0 ||
          recording.duration < const Duration(milliseconds: 400)) {
        if (recording != null) await _voiceRecorder.delete(recording);
        if (mounted) {
          setState(() {
            _recording = false;
            _recordPreparing = false;
            _paused = false;
          });
          _showMessage('Recording was too short.', 'রেকর্ডিং খুব ছোট হয়েছে।');
        }
        return;
      }

      if (mounted) {
        setState(() {
          _recording = false;
          _recordPreparing = false;
          _paused = false;
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
        final replyTarget = ref.read(chatProvider).replyToMessage;
        final effectiveParentId = replyTarget?.id ?? widget.parentId;
        await notifier.sendMessage(
          conversationId: widget.conversationId,
          body: '',
          parentId: effectiveParentId,
          attachments: [
            ChatAttachmentInput(
              fileUrl: presign.publicUrl,
              fileName: recording.fileName,
              contentType: RecordedVoiceMessage.contentType,
              sizeBytes: bytes.length,
            ),
          ],
        );
        notifier.setReplyToMessage(null);
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
          _paused = false;
          _recordElapsed = Duration.zero;
        });
      }
      _recordStopwatch.reset();
    }
  }

  Future<void> _shareContact() async {
    final member = await showShareContactSheet(context);
    if (member == null || !mounted) return;
    insertComposerText(_ctrl, formatSharedContact(member));
    setState(() => _forceExpanded = true);
    _focus.requestFocus();
  }

  void _showMessage(String english, String bangla) {
    if (!mounted) return;
    final language = ref.read(appLanguageProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(language == 'bn' ? bangla : english)),
    );
  }

  void _showMicPermissionSettings() {
    if (!mounted) return;
    final language = ref.read(appLanguageProvider);
    final isBn = language == 'bn';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isBn
              ? 'মাইক্রোফোন বন্ধ আছে। সেটিংস থেকে অনুমতি চালু করুন।'
              : 'Microphone access is blocked. Enable it in Settings.',
        ),
        action: SnackBarAction(
          label: isBn ? 'সেটিংস' : 'Settings',
          onPressed: openAppSettings,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<ChatMessage?>(
      chatProvider.select((s) => s.replyToMessage),
      (prev, next) {
        if (next != null && mounted) {
          setState(() => _forceExpanded = true);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _focus.requestFocus();
          });
        }
      },
    );

    final sending = ref.watch(chatProvider).sending;
    final language = ref.watch(appLanguageProvider);
    final replyToMsg = ref.watch(chatProvider).replyToMessage;
    String tr(String key) => AppTranslations.translate(context, ref, key);

    if (_voiceSheetOpen) {
      return ComposerRecordingBar(
        elapsed: _recordElapsed,
        preparing: _recordPreparing,
        uploading: _uploadingVoice,
        paused: _paused,
        viewOnce: _viewOnce,
        useBengaliDigits: language == 'bn',
        pauseLabel: tr('chat_voice_pause'),
        resumeLabel: tr('chat_voice_resume'),
        preparingLabel: tr('chat_recording_starting'),
        sendingLabel: tr('chat_voice_sending'),
        onDelete: () => unawaited(_cancelVoiceRecording()),
        onPauseToggle: () => unawaited(_togglePause()),
        onSend: () => unawaited(_finishVoiceRecording()),
        onViewOnceToggle: () => setState(() => _viewOnce = !_viewOnce),
      );
    }

    if (!_expanded) {
      return ComposerCollapsed(
        hint: _hint,
        onFocusTap: _openExpanded,
        onPlus: () => _attach(),
        onMic: () => unawaited(_startVoiceRecording()),
        voiceTooltip: tr('chat_tap_to_record'),
        preparingVoice: _recordPreparing,
      );
    }

    return ComposerExpandedShell(
      pending: _pending,
      onRemove: (i) => setState(() => _pending.removeAt(i)),
      onAddPhoto: () => _attach(),
      replyBanner: replyToMsg != null
          ? ComposerReplyBanner(
              message: replyToMsg,
              onCancel: () =>
                  ref.read(chatProvider.notifier).setReplyToMessage(null),
            )
          : null,
      field: ComposerSlackField(
        controller: _ctrl,
        focusNode: _focus,
        hint: _hint,
        sending: sending,
        canSend: _hasDraft,
        expanded: _tall,
        isGroup: widget.isGroup,
        onAttach: () => _attach(),
        onVoice: () => unawaited(_startVoiceRecording()),
        onShareContact: () => unawaited(_shareContact()),
        onMention: () => insertComposerAt(_ctrl),
        onExpand: () => setState(() => _tall = !_tall),
        onSend: _send,
        attachTooltip: tr('chat_attach'),
        voiceTooltip: tr('chat_tap_to_record'),
        shareContactTooltip: tr('chat_share_contact'),
        mentionTooltip: tr('chat_mention'),
        expandTooltip: tr('chat_expand'),
        sendLabel: tr('chat_send'),
      ),
    );
  }
}

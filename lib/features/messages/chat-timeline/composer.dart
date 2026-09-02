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
import '../providers/team_gate_provider.dart';
import 'composer_attach.dart';
import 'composer_attachment_panel.dart';
import 'composer_collapsed.dart';
import 'composer_expanded_shell.dart';
import 'composer_mention_picker.dart';
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
    this.onMessageSubmitted,
  });

  final String conversationId;
  final String? parentId;
  final String hintName;
  final String initialText;

  /// Channel/group — show @ mention beside share-contact.
  final bool isGroup;
  final VoidCallback? onMessageSubmitted;

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
  bool _attachmentPanelOpen = false;

  List<MentionCandidate> _mentionCandidates = [];
  final Set<String> _mentionedUserIds = {};
  bool _showMentions = false;
  int _mentionStartIndex = -1;

  String get _hint =>
      widget.parentId != null ? 'Add a reply' : 'Message ${widget.hintName}';
  bool get _hasDraft => _ctrl.text.trim().isNotEmpty || _pending.isNotEmpty;
  bool get _expanded =>
      _forceExpanded ||
      _focused ||
      _hasDraft ||
      ref.watch(chatProvider).replyToMessage != null;
  bool get _voiceSheetOpen => _recording || _recordPreparing || _uploadingVoice;

  List<MentionCandidate> _channelMembers = [];

  @override
  void initState() {
    super.initState();
    _loadChannelMembers();
    _ctrl = TextEditingController(text: widget.initialText)
      ..addListener(_onTextChanged);
    _focus = FocusNode()..addListener(_onFocus);
  }

  Future<void> _loadChannelMembers() async {
    try {
      final members = await ref
          .read(chatProvider.notifier)
          .listChannelMembers(widget.conversationId);
      if (mounted) {
        setState(() {
          _channelMembers = members
              .map(
                (m) => MentionCandidate(userId: m.userId, displayName: m.name),
              )
              .toList();
        });
      }
    } catch (_) {}
  }

  void _onTextChanged() {
    setState(() {});
    final text = _ctrl.text;
    final sel = _ctrl.selection;

    if (!sel.isValid || !sel.isCollapsed) {
      if (_showMentions) setState(() => _showMentions = false);
      return;
    }

    final cursor = sel.start;
    final beforeCursor = text.substring(0, cursor);
    final lastAt = beforeCursor.lastIndexOf('@');

    if (lastAt != -1) {
      final query = beforeCursor.substring(lastAt + 1);
      if (!query.contains(' ') && !query.contains('\n')) {
        _mentionStartIndex = lastAt;
        _updateMentionCandidates(query);
        return;
      }
    }

    if (_showMentions) setState(() => _showMentions = false);
  }

  void _updateMentionCandidates(String query) {
    final teamMembers = ref.read(teamMembersProvider);
    final chatState = ref.read(chatProvider);
    final currentUserId = chatState.currentUserId;

    final map = <String, MentionCandidate>{};

    // 1. Add channel members
    for (final cm in _channelMembers) {
      if (cm.userId.isNotEmpty && cm.userId != currentUserId) {
        map[cm.userId] = cm;
      }
    }

    // 2. Add team members
    for (final tm in teamMembers) {
      if (tm.userId.isNotEmpty && tm.userId != currentUserId) {
        map[tm.userId] = MentionCandidate(
          userId: tm.userId,
          displayName: tm.displayName,
          avatarUrl: tm.avatarUrl,
        );
      }
    }

    // 3. Add DM peers
    for (final dm in chatState.dms) {
      final peerId = dm.peerUserId;
      final peerName = dm.peerUserName;
      if (peerId != null &&
          peerId.isNotEmpty &&
          peerId != currentUserId &&
          peerName != null &&
          peerName.isNotEmpty) {
        map.putIfAbsent(
          peerId,
          () => MentionCandidate(
            userId: peerId,
            displayName: peerName,
            avatarUrl: dm.peerUserAvatar,
          ),
        );
      }
    }

    final q = query.toLowerCase();
    final candidates = map.values
        .where((c) => q.isEmpty || c.displayName.toLowerCase().contains(q))
        .toList();

    setState(() {
      _mentionCandidates = candidates;
      _showMentions = candidates.isNotEmpty;
    });
  }

  void _selectMention(MentionCandidate candidate) {
    if (_mentionStartIndex == -1) return;
    final text = _ctrl.text;
    final cursor = _ctrl.selection.isValid
        ? _ctrl.selection.start
        : text.length;

    final before = text.substring(0, _mentionStartIndex);
    final after = cursor <= text.length ? text.substring(cursor) : '';
    final inserted = '@${candidate.displayName} ';

    _ctrl.value = TextEditingValue(
      text: '$before$inserted$after',
      selection: TextSelection.collapsed(
        offset: before.length + inserted.length,
      ),
    );

    _mentionedUserIds.add(candidate.userId);
    setState(() => _showMentions = false);
  }

  void _triggerMention() {
    insertComposerAt(_ctrl);
    _onTextChanged();
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
    ref.read(chatProvider.notifier).setReplyToMessage(null);
    final body = plain.isEmpty ? '' : textToTiptapJson(plain);
    final attachments = List<ChatAttachmentInput>.of(_pending);
    final mentionedIds = _mentionedUserIds.toList();

    _mentionedUserIds.clear();
    if (!mounted) return;
    _ctrl.clear();
    setState(() {
      _pending.clear();
      _showMentions = false;
      _forceExpanded = true;
    });

    // Start the optimistic insert before asking the timeline to reveal it.
    // Keep this compose session focused, matching Signal's continuous-send UX.
    // The conversation id must be the one on screen: sendMessage falls back to
    // the shared activeConversationId, which a background fetchSidebar can
    // null out, and a null id drops the send with no bubble and no error.
    final sendFuture = ref
        .read(chatProvider.notifier)
        .sendMessage(
          conversationId: widget.conversationId,
          body: body,
          attachments: attachments,
          mentionedUserIds: mentionedIds,
          parentId: effectiveParentId,
        );
    widget.onMessageSubmitted?.call();
    if (!_focus.hasFocus) _focus.requestFocus();
    final sentMsg = await sendFuture;

    // Slack parity: Check if any mentioned users are not members of this channel/group
    if (widget.isGroup &&
        sentMsg != null &&
        mentionedIds.isNotEmpty &&
        mounted) {
      _checkNotInChannelMentions(sentMsg, mentionedIds);
    }
  }

  void _checkNotInChannelMentions(
    ChatMessage sentMsg,
    List<String> mentionedIds,
  ) {
    final channelUserIds = _channelMembers.map((m) => m.userId).toSet();
    final nonMembers = _mentionCandidates
        .where(
          (c) =>
              !channelUserIds.contains(c.userId) &&
              mentionedIds.contains(c.userId),
        )
        .toList();

    if (nonMembers.isNotEmpty) {
      _showNotInChannelDialog(
        context,
        ref,
        widget.conversationId,
        sentMsg,
        nonMembers,
        onAdded: _loadChannelMembers,
      );
    }
  }

  Future<void> _attach({ImageSource? source, ComposerAttachKind? kind}) async {
    if (!mounted) return;
    try {
      await pickAndUploadAttachment(
        context,
        ref,
        conversationId: widget.conversationId,
        source: source,
        kind: kind,
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

  void _toggleAttachmentPanel() {
    _focus.unfocus();
    setState(() => _attachmentPanelOpen = !_attachmentPanelOpen);
  }

  void _closeAttachmentPanel() {
    if (_attachmentPanelOpen) setState(() => _attachmentPanelOpen = false);
  }

  void _selectAttachment(ComposerAttachKind kind) {
    _closeAttachmentPanel();
    unawaited(_attach(kind: kind));
  }

  void _selectContact() {
    _closeAttachmentPanel();
    unawaited(_shareContact());
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
    ref.listen<ChatMessage?>(chatProvider.select((s) => s.replyToMessage), (
      prev,
      next,
    ) {
      if (next != null && mounted) {
        setState(() => _forceExpanded = true);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _focus.requestFocus();
        });
      }
    });

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

    final composer = !_expanded
        ? ComposerCollapsed(
            hint: _hint,
            onFocusTap: () {
              _closeAttachmentPanel();
              _openExpanded();
            },
            onPlus: _toggleAttachmentPanel,
            onMic: () => unawaited(_startVoiceRecording()),
            voiceTooltip: tr('chat_tap_to_record'),
            preparingVoice: _recordPreparing,
          )
        : ComposerExpandedShell(
            pending: _pending,
            onRemove: (i) => setState(() => _pending.removeAt(i)),
            onReorder: (oldIndex, newIndex) => setState(() {
              _pending.insert(newIndex, _pending.removeAt(oldIndex));
            }),
            onAddPhoto: () => _attach(kind: ComposerAttachKind.gallery),
            mentionPicker: _showMentions
                ? ComposerMentionPicker(
                    candidates: _mentionCandidates,
                    onSelect: _selectMention,
                  )
                : null,
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
              onAttach: _toggleAttachmentPanel,
              onVoice: () => unawaited(_startVoiceRecording()),
              onShareContact: () => unawaited(_shareContact()),
              onMention: _triggerMention,
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

    return PopScope(
      canPop: !_attachmentPanelOpen,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _closeAttachmentPanel();
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          composer,
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            child: _attachmentPanelOpen
                ? ComposerAttachmentPanel(
                    galleryLabel: tr('chat_gallery'),
                    cameraLabel: tr('chat_camera'),
                    fileLabel: tr('chat_file'),
                    contactLabel: tr('chat_contact'),
                    onGallery: () =>
                        _selectAttachment(ComposerAttachKind.gallery),
                    onCamera: () =>
                        _selectAttachment(ComposerAttachKind.camera),
                    onFile: () => _selectAttachment(ComposerAttachKind.file),
                    onContact: _selectContact,
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

Future<void> _showNotInChannelDialog(
  BuildContext context,
  WidgetRef ref,
  String conversationId,
  ChatMessage sentMsg,
  List<MentionCandidate> nonMembers, {
  VoidCallback? onAdded,
}) async {
  final names = nonMembers.map((m) => '@${m.displayName}').join(', ');
  final isPlural = nonMembers.length > 1;

  await showDialog<void>(
    context: context,
    builder: (dialogCtx) {
      final colors = Theme.of(dialogCtx).colorScheme;
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            Icon(Icons.person_add_outlined, color: colors.primary, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                isPlural ? 'Users not in channel' : 'User not in channel',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          '$names ${isPlural ? "are" : "is"} mentioned, but not in this channel. Would you like to add ${isPlural ? "them" : "them"} to this channel or remove the message?',
          style: const TextStyle(fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogCtx);
              await ref.read(chatProvider.notifier).deleteMessage(sentMsg.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Message removed')),
                );
              }
            },
            child: Text(
              'Remove message',
              style: TextStyle(
                color: colors.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Do nothing'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(dialogCtx);
              for (final member in nonMembers) {
                try {
                  await ref
                      .read(chatProvider.notifier)
                      .addChannelMember(conversationId, member.userId);
                } catch (_) {}
              }
              await ref.read(chatProvider.notifier).fetchSidebar(silent: true);
              onAdded?.call();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Added $names to the channel')),
                );
              }
            },
            child: const Text('Add to channel'),
          ),
        ],
      );
    },
  );
}

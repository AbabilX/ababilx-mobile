import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/localization/app_translations.dart';
import '../../jpack/screens/jpack_cover_gallery_screen.dart';
import '../../ghost/widgets/ghost_intro_sheet.dart';
import '../../attachments/providers/attachment_providers.dart';
import '../../../shared/media/device_gallery.dart';
import '../data/models/chat_models.dart';
import '../data/local/composer_draft_store.dart';
import '../data/chat_client_message_id.dart';
import '../providers/chat_provider.dart';
import '../tiptap_encode.dart';
import '../providers/team_gate_provider.dart';
import 'composer_attach.dart';
import 'composer_uploads_gate.dart';
import 'composer_attachment_keyboard.dart';
import 'composer_expanded_shell.dart';
import 'composer_input_bar.dart';
import 'composer_mention_picker.dart';
import 'composer_recording_bar.dart';
import 'composer_recent_review.dart';
import 'composer_recent_selection.dart';
import 'composer_recent_selection_badge.dart';
import 'composer_recent_selection_label.dart';
import 'composer_reply_banner.dart';
import 'composer_reply_target.dart';
import 'reaction_emoji_picker.dart';
import 'composer_share_contact.dart';
import 'composer_text_actions.dart';
import 'voice_message_recorder.dart';
import '../../../shared/text/name_search.dart';
import '../../../core/network/ws_client.dart';
import '../../settings/typing-indicators/typing_indicators_provider.dart';
import '../chat-typing/typing_sender.dart';

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
  static const int _maxAttachments = 10;
  late final TextEditingController _ctrl;
  late final FocusNode _focus;
  late final ComposerDraftStore _draftStore;
  String _draftOwnerId = '';
  final _voiceRecorder = VoiceMessageRecorder();
  final _recordStopwatch = Stopwatch();
  final _pending = <ChatAttachmentInput>[];
  final _progressByUrl = <String, (int, int)>{};
  final _uploadBubbleByUrl = <String, _UploadBubble>{};
  List<DeviceMediaItem> _selectedRecent = const [];

  /// Attachment uploads still travelling. A tile is drawn as soon as its URL
  /// is reserved, so the send path has to wait these out or it would post a
  /// message pointing at an object that is not in the bucket yet.
  final _uploads = ComposerUploads();
  Timer? _recordClock;
  Duration _recordElapsed = Duration.zero;
  bool _recording = false;
  bool _recordPreparing = false;
  bool _recordFinishing = false;
  bool _uploadingVoice = false;
  bool _paused = false;
  bool _viewOnce = false;
  bool _attachmentPanelOpen = false;
  bool _restoringDraft = true;
  bool _persistTextChanges = true;
  bool _sendInFlight = false;

  List<MentionCandidate> _mentionCandidates = [];
  final Set<String> _mentionedUserIds = {};

  /// Display name -> user id for everyone picked from the popover this compose
  /// session. The field itself is plain text, so this is the only record of
  /// which run of characters was a person; the encoder turns it back into
  /// mention nodes at send time.
  final Map<String, String> _mentionByLabel = {};
  bool _showMentions = false;
  int _mentionStartIndex = -1;

  String get _hint =>
      widget.parentId != null ? 'Add a reply' : 'Message ${widget.hintName}';
  bool get _hasDraft =>
      _ctrl.text.trim().isNotEmpty ||
      _pending.isNotEmpty ||
      _selectedRecent.isNotEmpty;
  bool get _voiceSheetOpen => _recording || _recordPreparing || _uploadingVoice;

  List<MentionCandidate> _channelMembers = [];

  /// Top-level composer only: typing is scoped to the conversation, and a
  /// thread reply announcing itself there would point at the wrong place.
  ChatTypingSender? _typing;

  /// Leaving the app mid-draft stops "typing…" at once instead of leaving it
  /// to the receivers' 5 s expiry — web does the same on visibilitychange.
  AppLifecycleListener? _typingLifecycle;

  @override
  void initState() {
    super.initState();
    _draftStore = ref.read(composerDraftStoreProvider);
    _draftOwnerId = ref.read(chatProvider).currentUserId;
    _loadChannelMembers();
    _ctrl = TextEditingController(text: widget.initialText)
      ..addListener(_onTextChanged);
    _focus = FocusNode()..addListener(_onFocus);
    if (widget.parentId == null) {
      _typing = ChatTypingSender(
        ws: ref.read(wsClientProvider),
        conversationId: widget.conversationId,
        enabled: () => ref.read(typingIndicatorsProvider),
      );
      _typingLifecycle = AppLifecycleListener(
        onHide: () => _typing?.stop(),
        onPause: () => _typing?.stop(),
      );
    }
    unawaited(_restoreDraft());
  }

  Future<void> _restoreDraft() async {
    if (widget.initialText.isNotEmpty) {
      _restoringDraft = false;
      return;
    }
    if (_draftOwnerId.isEmpty) {
      final ownerId = await ref.read(chatProvider.notifier).localUserId();
      if (!mounted) return;
      _draftOwnerId = ownerId;
    }
    final draft = await _draftStore.read(
      _draftOwnerId,
      widget.conversationId,
      parentId: widget.parentId,
    );
    if (!mounted) return;
    _restoringDraft = false;
    // Never replace text the user entered while the disk read was in flight.
    if (_ctrl.text.isEmpty && draft.isNotEmpty) {
      _persistTextChanges = false;
      _ctrl.value = TextEditingValue(
        text: draft,
        selection: TextSelection.collapsed(offset: draft.length),
      );
      _persistTextChanges = true;
    } else if (_ctrl.text.isNotEmpty && _ctrl.text != draft) {
      // The user typed before the async read completed. Persist their newer
      // value now; waiting for another keystroke would lose it on a quick kill.
      unawaited(
        _draftStore.write(
          _draftOwnerId,
          widget.conversationId,
          _ctrl.text,
          parentId: widget.parentId,
        ),
      );
    }
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
    if (_persistTextChanges) {
      // Only a person's edit announces typing — never a restored draft.
      if (!_restoringDraft) _typing?.onText(text);
    }
    if (!_restoringDraft && _persistTextChanges) {
      unawaited(
        _draftStore.write(
          _draftOwnerId,
          widget.conversationId,
          text,
          parentId: widget.parentId,
        ),
      );
    }
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

    final candidates = map.values
        .where((c) => matchesNameQuery(query, [c.displayName]))
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
    _mentionByLabel[candidate.displayName] = candidate.userId;
    setState(() => _showMentions = false);
  }

  void _onFocus() {
    // The bar never changes shape on focus the way the old Slack composer
    // did; this only closes the attachment keyboard when the text field wins
    // focus back, so the two are never up at once.
    if (_focus.hasFocus) _closeAttachmentPanel();
  }

  @override
  void dispose() {
    _typing?.stop();
    _typingLifecycle?.dispose();
    _recordClock?.cancel();
    unawaited(_voiceRecorder.dispose());
    // An empty controller during restore does not mean an empty draft; nor
    // does the optimistic clear while a send is still unresolved.
    if (!((_restoringDraft || _sendInFlight) && _ctrl.text.isEmpty)) {
      unawaited(
        _draftStore.write(
          _draftOwnerId,
          widget.conversationId,
          _ctrl.text,
          parentId: widget.parentId,
        ),
      );
    }
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_selectedRecent.isNotEmpty) {
      await _reviewSelectedRecents();
      return;
    }
    final plain = _ctrl.text.trim();
    if (plain.isEmpty && _pending.isEmpty) return;
    final uploading = _uploads.busy;
    final reply = ComposerReplyTarget.resolve(
      replyTo: ref.read(chatProvider).replyToMessage,
      threadRootId: widget.parentId,
    );
    ref.read(chatProvider.notifier).setReplyToMessage(null);
    final body = plain.isEmpty
        ? ''
        : encodeTiptapBody(plain: plain, mentionByLabel: _mentionByLabel);
    final attachments = List<ChatAttachmentInput>.of(_pending);
    final mentionedIds = _mentionedUserIds.toList();

    final notifier = ref.read(chatProvider.notifier);
    String? clientRef;
    _UploadBubble? uploadBubble;
    if (uploading) {
      clientRef = await notifier.beginUploadingMessage(
        conversationId: widget.conversationId,
        body: body,
        attachments: attachments,
        mentionedUserIds: mentionedIds,
        parentId: reply.parentId,
        quotedMessageId: reply.quotedMessageId,
        quotePreview: reply.preview,
      );
      if (clientRef == null || !mounted) return;
      uploadBubble = _UploadBubble(
        clientRef: clientRef,
        parentId: reply.parentId,
        attachments: attachments,
      );
      for (final attachment in attachments) {
        _uploadBubbleByUrl[attachment.fileUrl] = uploadBubble;
      }
      _publishUploadProgress(uploadBubble);
    }
    clientRef ??= newChatClientMessageId();
    await _draftStore.bindSend(
      _draftOwnerId,
      widget.conversationId,
      clientRef,
      _ctrl.text,
      parentId: widget.parentId,
    );
    _mentionedUserIds.clear();
    _mentionByLabel.clear();
    if (!mounted) return;
    // Clear the visible composer immediately, but retain the durable draft
    // until delivery succeeds. If the send fails, recreation restores the
    // text; if the user starts another draft meanwhile, that newer text wins.
    _persistTextChanges = false;
    _sendInFlight = true;
    _typing?.stop();
    _ctrl.clear();
    _persistTextChanges = true;
    setState(() {
      _pending.clear();
      _showMentions = false;
    });

    // Start the optimistic insert before asking the timeline to reveal it.
    // Keep this compose session focused, matching Signal's continuous-send UX.
    // The conversation id must be the one on screen: sendMessage falls back to
    // the shared activeConversationId, which a background fetchSidebar can
    // null out, and a null id drops the send with no bubble and no error.
    widget.onMessageSubmitted?.call();
    if (!_focus.hasFocus) _focus.requestFocus();
    if (uploading) {
      await _uploads.settleCurrent();
      for (final attachment in attachments) {
        _uploadBubbleByUrl.remove(attachment.fileUrl);
        _progressByUrl.remove(attachment.fileUrl);
      }
      if (!mounted) return;
      if (uploadBubble!.attachments.isEmpty && body.isEmpty) {
        _sendInFlight = false;
        notifier.removeUploadingMessage(
          widget.conversationId,
          clientRef,
          parentId: reply.parentId,
        );
        _showMessage(
          'Could not upload this file. Please select it again.',
          'ফাইল আপলোড করা যায়নি। আবার ফাইলটি নির্বাচন করুন।',
        );
        return;
      }
    }
    final sentMsg = await notifier.sendMessage(
      conversationId: widget.conversationId,
      body: body,
      attachments: uploadBubble?.attachments ?? attachments,
      mentionedUserIds: mentionedIds,
      parentId: reply.parentId,
      quotedMessageId: reply.quotedMessageId,
      quotePreview: reply.preview,
      clientMessageId: clientRef,
      reusePending: uploading,
    );
    _sendInFlight = false;
    if (sentMsg != null) {
      await _draftStore.completeSend(
        _draftOwnerId,
        widget.conversationId,
        clientRef,
        parentId: widget.parentId,
      );
    }
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

  /// An attachment whose upload failed leaves the strip: the tile was drawn
  /// optimistically against a reserved URL, and that object will never exist.
  void _dropPending(String fileUrl) {
    if (!mounted) return;
    final bubble = _uploadBubbleByUrl.remove(fileUrl);
    bubble?.attachments.removeWhere((a) => a.fileUrl == fileUrl);
    if (bubble != null) _publishUploadProgress(bubble);
    setState(() {
      _pending.removeWhere((a) => a.fileUrl == fileUrl);
    });
  }

  void _onUploadProgress(String fileUrl, int sent, int total) {
    _progressByUrl[fileUrl] = (sent, total);
    final bubble = _uploadBubbleByUrl[fileUrl];
    if (bubble != null) _publishUploadProgress(bubble);
  }

  void _publishUploadProgress(_UploadBubble bubble) {
    var sent = 0;
    var total = 0;
    for (final attachment in bubble.attachments) {
      final sample = _progressByUrl[attachment.fileUrl];
      sent += sample?.$1 ?? 0;
      total += sample?.$2 ?? attachment.sizeBytes;
    }
    ref
        .read(chatProvider.notifier)
        .updatePendingUploadProgress(
          widget.conversationId,
          bubble.clientRef,
          total == 0 ? 0 : sent / total,
          parentId: bubble.parentId,
        );
  }

  Future<void> _attach({ImageSource? source, ComposerAttachKind? kind}) async {
    if (!mounted) return;
    try {
      final run = pickAndUploadAttachment(
        context,
        ref,
        conversationId: widget.conversationId,
        source: source,
        kind: kind,
        onAdded: (a) {
          if (!mounted) return;
          setState(() => _pending.add(a));
          _focus.requestFocus();
        },
        onFailed: _dropPending,
        onProgress: _onUploadProgress,
        onNativeSendReady: (caption) {
          if (!mounted) return;
          if (caption.isNotEmpty) _ctrl.text = caption;
          unawaited(_send());
        },
      );
      _uploads.track(run);
      final outcome = await run;
      // The native review screen ends on its own Send: the album and the one
      // message typed under it go out without a second trip to the composer.
      if (outcome.sendRequested && mounted) {
        if (outcome.caption.isNotEmpty) _ctrl.text = outcome.caption;
        await _send();
      }
    } on ChatAttachmentSizeException {
      if (!mounted) return;
      _showMessage(
        'Files must be 350 MB or smaller.',
        'ফাইল ৩৫০ MB বা তার কম হতে হবে।',
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

  void _openAttachmentPanel() {
    _focus.unfocus();
    if (!_attachmentPanelOpen) {
      setState(() => _attachmentPanelOpen = true);
    }
  }

  void _clearRecentSelection() {
    if (_selectedRecent.isEmpty) return;
    setState(() => _selectedRecent = const []);
  }

  void _selectAttachment(ComposerAttachKind kind) {
    _closeAttachmentPanel();
    unawaited(_attach(kind: kind));
  }

  /// Rail taps only select. Upload starts after the native review/edit step.
  void _pickFromRail(DeviceMediaItem item) {
    if (!_selectedRecent.contains(item) &&
        _pending.length + _selectedRecent.length >= _maxAttachments) {
      _showMessage(
        'You can attach up to 10 files.',
        'সর্বোচ্চ ১০টি ফাইল সংযুক্ত করা যাবে।',
      );
      return;
    }
    setState(
      () => _selectedRecent = toggleRecentSelection(_selectedRecent, item),
    );
  }

  Future<void> _reviewSelectedRecents() async {
    final selected = List<DeviceMediaItem>.of(_selectedRecent);
    if (selected.isEmpty) return;
    try {
      final run = reviewAndUploadRecentMedia(
        ref,
        conversationId: widget.conversationId,
        items: selected,
        maxSelection: _maxAttachments - _pending.length,
        initialCaption: _ctrl.text,
        onAccepted: (caption) {
          if (!mounted) return;
          setState(() {
            _selectedRecent = const [];
            _attachmentPanelOpen = false;
          });
          _ctrl.text = caption;
        },
        onAdded: (attachment) {
          if (!mounted) return;
          setState(() => _pending.add(attachment));
        },
        onFailed: _dropPending,
        onProgress: _onUploadProgress,
        onReady: () => unawaited(_send()),
      );
      _uploads.track(run);
      await run;
    } on ChatAttachmentSizeException {
      _showMessage(
        'Files must be 350 MB or smaller.',
        'ফাইল ৩৫০ MB বা তার কম হতে হবে।',
      );
    } catch (_) {
      _showMessage('Could not attach this file.', 'ফাইল সংযুক্ত করা যায়নি।');
    }
  }

  void _removePendingAt(int index) {
    setState(() => _pending.removeAt(index));
  }

  Future<void> _pickEmoji() async {
    final emoji = await showReactionEmojiPicker(context);
    if (emoji == null || !mounted) return;
    insertComposerText(_ctrl, emoji);
    _focus.requestFocus();
  }

  void _selectContact() {
    _closeAttachmentPanel();
    unawaited(_shareContact());
  }

  /// JPack is one sender, one receiver: offered in a DM with a peer, on the
  /// main timeline only.
  VoidCallback? get _jpackAction {
    if (widget.parentId != null) return null;
    final conv = ref.read(chatProvider).conversationById(widget.conversationId);
    if (conv == null || !conv.hasDmPeer) return null;
    return () {
      _closeAttachmentPanel();
      unawaited(
        openJPackFlow(
          context,
          conversationId: widget.conversationId,
          recipientName: conv.displayTitle(
            ref.read(chatProvider).currentUserId,
          ),
        ),
      );
    };
  }

  /// Ghost Chat: a DM with an accepted connection, main timeline only. The
  /// server refuses anything else; hiding the chip keeps a pending request
  /// from offering a button that can only fail. `requestState` is `none` for
  /// an accepted connection and for a thread nobody answered, so the server
  /// still has the final word on the second.
  VoidCallback? get _ghostAction {
    if (widget.parentId != null) return null;
    final conv = ref.read(chatProvider).conversationById(widget.conversationId);
    if (conv == null || !conv.hasDmPeer || !conv.canMessage) return null;
    if (conv.requestState != 'none') return null;
    return () {
      _closeAttachmentPanel();
      unawaited(
        showGhostIntroSheet(context, conversationId: widget.conversationId),
      );
    };
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
        await ref
            .read(attachmentAdopterProvider)
            .adoptBytes(
              fileUrl: presign.publicUrl,
              fileName: recording.fileName,
              contentType: RecordedVoiceMessage.contentType,
              bytes: bytes,
            );
        final reply = ComposerReplyTarget.resolve(
          replyTo: ref.read(chatProvider).replyToMessage,
          threadRootId: widget.parentId,
        );
        await notifier.sendMessage(
          conversationId: widget.conversationId,
          body: '',
          parentId: reply.parentId,
          quotedMessageId: reply.quotedMessageId,
          quotePreview: reply.preview,
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

    final composer = ComposerExpandedShell(
      pending: _pending,
      onRemove: _removePendingAt,
      onReorder: (oldIndex, newIndex) => setState(() {
        _pending.insert(newIndex, _pending.removeAt(oldIndex));
      }),
      onAddPhoto: () => _attach(kind: ComposerAttachKind.gallery),
      selectionBadge:
          !_attachmentPanelOpen && _selectedRecent.isNotEmpty
          ? ComposerRecentSelectionBadge(
              label: recentSelectionBadgeLabel(
                photoCount: _selectedRecent.where((i) => !i.isVideo).length,
                videoCount: _selectedRecent.where((i) => i.isVideo).length,
                bengali: language == 'bn',
              ),
              onTap: _openAttachmentPanel,
              onClear: _clearRecentSelection,
              clearTooltip: tr('chat_clear_selection'),
            )
          : null,
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
      field: ComposerInputBar(
        controller: _ctrl,
        focusNode: _focus,
        hint: _hint,
        sending: sending,
        canSend: _hasDraft,
        attachmentOpen: _attachmentPanelOpen,
        preparingVoice: _recordPreparing,
        onEmoji: () => unawaited(_pickEmoji()),
        onCamera: () => _selectAttachment(ComposerAttachKind.camera),
        onVoice: () => unawaited(_startVoiceRecording()),
        onPlus: _toggleAttachmentPanel,
        onSend: _send,
        cameraTooltip: tr('chat_camera'),
        voiceTooltip: tr('chat_tap_to_record'),
        attachTooltip: tr('chat_attach'),
        sendLabel: tr(_selectedRecent.isEmpty ? 'chat_send' : 'chat_next'),
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
                ? ComposerAttachmentKeyboard(
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
                    jpackLabel: tr('jpack_chip'),
                    onJPack: _jpackAction,
                    ghostLabel: tr('ghost_chip'),
                    onGhost: _ghostAction,
                    onPickMedia: _pickFromRail,
                    selectedMediaUris: [
                      for (final item in _selectedRecent) item.uri,
                    ],
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _UploadBubble {
  _UploadBubble({
    required this.clientRef,
    required this.parentId,
    required List<ChatAttachmentInput> attachments,
  }) : attachments = List.of(attachments);

  final String clientRef;
  final String? parentId;
  final List<ChatAttachmentInput> attachments;
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

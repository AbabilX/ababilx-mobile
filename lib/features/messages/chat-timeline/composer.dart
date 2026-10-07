import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../privacy-mode/privacy_media.dart';
import '../../../core/localization/app_translations.dart';
import '../../khaam/screens/khaam_cover_gallery_screen.dart';
import '../../ghost/widgets/ghost_intro_sheet.dart';
import '../../attachments/providers/attachment_providers.dart';
import '../../../shared/media/device_gallery.dart';
import '../chat-details/group_permissions.dart';
import '../data/models/chat_models.dart';
import '../data/local/composer_draft_store.dart';
import '../data/chat_client_message_id.dart';
import '../providers/chat_provider.dart';
import '../tiptap_encode.dart';
import '../providers/chat_connections_provider.dart';
import '../providers/messageable_people_provider.dart';
import 'composer_attach.dart';
import 'composer_uploads_gate.dart';
import 'composer_attachment_keyboard.dart';
import 'composer_expanded_shell.dart';
import 'composer_input_bar.dart';
import 'composer_keyboard_content.dart';
import 'composer_upload.dart';
import 'composer_highlight_controller.dart';
import 'composer_mention_candidates.dart';
import 'composer_mention_picker.dart';
import 'composer_recording_bar.dart';
import 'composer_recent_review.dart';
import 'composer_recent_selection.dart';
import 'composer_recent_selection_badge.dart';
import 'composer_recent_selection_label.dart';
import 'composer_reply_banner.dart';
import 'composer_reply_target.dart';
import 'reaction_emoji_picker.dart';
import 'composer_text_actions.dart';
import 'voice_message_recorder.dart';
import '../../../core/network/ws_client.dart';
import '../../settings/typing-indicators/typing_indicators_provider.dart';
import '../chat-typing/typing_sender.dart';
import '../group-member-permissions/group_media_guard.dart';
import '../../../shared/widgets/app_toast.dart';

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

  /// Set when the user cancels an uploading bubble mid-flight.
  bool _sendCancelled = false;

  List<MentionCandidate> _mentionCandidates = [];
  final Set<String> _mentionedUserIds = {};

  /// Display name -> user id for everyone picked from the popover this compose
  /// session. The field itself is plain text, so this is the only record of
  /// which run of characters was a person; the encoder turns it back into
  /// mention nodes at send time.
  final Map<String, String> _mentionByLabel = {};

  /// `@all` was picked, so the draft paints it like any other mention.
  bool _pickedAll = false;
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
  bool _channelMembersLoaded = false;

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
    _ctrl = ComposerHighlightController(
      text: widget.initialText,
      mentionLabels: () => [..._mentionByLabel.keys, if (_pickedAll) 'all'],
    )..addListener(_onTextChanged);
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
    final String draft;
    try {
      if (_draftOwnerId.isEmpty) {
        final ownerId = await ref.read(chatProvider.notifier).localUserId();
        if (!mounted) return;
        _draftOwnerId = ownerId;
      }
      draft = await _draftStore.read(
        _draftOwnerId,
        widget.conversationId,
        parentId: widget.parentId,
      );
    } catch (_) {
      // A draft that cannot be read is lost, not a reason to keep this
      // composer in "restoring" for its whole life — that silenced typing
      // indicators (and draft saving) until the chat was reopened.
      if (mounted) _restoringDraft = false;
      return;
    }
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
    // A DM's only candidate is the peer, already on the conversation row.
    if (!widget.isGroup) return;
    // Outsiders are accepted connections. Nothing else loads that list unless
    // the People screen was opened this session, so ask for it here. The
    // notifier shares an in-flight request, so this costs nothing extra.
    unawaited(
      ref
          .read(chatConnectionsProvider.notifier)
          .refresh()
          .then((_) => _refreshOpenMentions()),
    );
    try {
      final members = await ref
          .read(chatProvider.notifier)
          .listChannelMembers(widget.conversationId);
      if (!mounted) return;
      setState(() {
        _channelMembers = [
          for (final m in members)
            MentionCandidate(
              userId: m.userId,
              displayName: m.name,
              avatarUrl: m.avatarUrl,
            ),
        ];
        _channelMembersLoaded = true;
      });
      _refreshOpenMentions();
    } catch (_) {}
  }

  void _refreshOpenMentions() {
    if (mounted && _focus.hasFocus) _syncMentions();
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
    _syncMentions();
  }

  /// Opens, refreshes or closes the `@` popover for the text at the cursor.
  /// Also run when members or connections finish loading, so a popover opened
  /// before they arrived fills in instead of staying short.
  void _syncMentions() {
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
    final chat = ref.read(chatProvider);
    final candidates = buildMentionCandidates(
      conversation: chat.conversationById(widget.conversationId),
      currentUserId: chat.currentUserId,
      members: _channelMembers,
      membersLoaded: _channelMembersLoaded,
      connections: ref.read(groupInvitablePeopleProvider),
      query: query,
    );

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

    if (candidate.isAll) {
      // "@all" stays plain text (no mention node every client would have to
      // learn); the notification half is every member's id on the send.
      final me = ref.read(chatProvider).currentUserId;
      _pickedAll = true;
      _mentionedUserIds.addAll(
        _channelMembers.map((m) => m.userId).where((id) => id != me),
      );
    } else {
      _mentionedUserIds.add(candidate.userId);
      _mentionByLabel[candidate.displayName] = candidate.userId;
    }
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

  /// Posts the draft: typed text plus the pending strip.
  ///
  /// [only] posts those attachments alone instead — a keyboard sticker or
  /// GIF, which goes out the moment it is inserted, as on Signal and
  /// WhatsApp. The typed text, its mentions and the pending strip stay where
  /// they are for the next send.
  Future<void> _send({List<ChatAttachmentInput>? only}) async {
    // The native review screen calls back after its Activity closes; a
    // composer rebuilt meanwhile must not run the send on a dead `ref`.
    if (!mounted) return;
    final draftSend = only == null;
    if (draftSend && _selectedRecent.isNotEmpty) {
      await _reviewSelectedRecents();
      return;
    }
    final plain = draftSend ? _ctrl.text.trim() : '';
    var outgoing = List<ChatAttachmentInput>.of(only ?? _pending);
    if (plain.isEmpty && outgoing.isEmpty) return;
    // Privacy mode: after the preview, the timer / saving sheet (server 0152).
    // Only a send carrying attachments waits for it; text goes straight out.
    if (outgoing.isNotEmpty) {
      final ruled = await askPrivacyMediaRules(
        context,
        ref,
        ref.read(chatProvider).conversationById(widget.conversationId),
        outgoing,
      );
      if (ruled == null || !mounted) return;
      outgoing = List.of(ruled);
      if (draftSend) {
        _pending
          ..clear()
          ..addAll(ruled);
      }
    }
    final uploading = _uploads.busy;
    final reply = ComposerReplyTarget.resolve(
      replyTo: ref.read(chatProvider).replyToMessage,
      threadRootId: widget.parentId,
    );
    ref.read(chatProvider.notifier).setReplyToMessage(null);
    final body = plain.isEmpty
        ? ''
        : encodeTiptapBody(plain: plain, mentionByLabel: _mentionByLabel);
    final attachments = outgoing;
    final mentionedIds = draftSend ? _mentionedUserIds.toList() : <String>[];

    final notifier = ref.read(chatProvider.notifier);
    String? clientRef;
    _UploadBubble? uploadBubble;
    _sendCancelled = false;
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
      notifier.registerUploadingCancel(clientRef, () {
        _sendCancelled = true;
        _uploads.cancelAll();
      });
      _publishUploadProgress(uploadBubble);
    }
    clientRef ??= newChatClientMessageId();
    if (draftSend) {
      await _draftStore.bindSend(
        _draftOwnerId,
        widget.conversationId,
        clientRef,
        _ctrl.text,
        parentId: widget.parentId,
      );
      _mentionedUserIds.clear();
      _mentionByLabel.clear();
      _pickedAll = false;
      if (!mounted) return;
      // Clear the visible composer immediately, but retain the durable draft
      // until delivery succeeds. If the send fails, recreation restores the
      // text; if the user starts another draft meanwhile, that newer text
      // wins.
      _persistTextChanges = false;
      _sendInFlight = true;
      _typing?.stop();
      _ctrl.clear();
      _persistTextChanges = true;
      setState(() {
        _pending.clear();
        _showMentions = false;
      });
    }

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
      if (_sendCancelled) {
        if (draftSend) _sendInFlight = false;
        notifier.removeUploadingMessage(
          widget.conversationId,
          clientRef,
          parentId: reply.parentId,
        );
        return;
      }
      // Dio often never reports 100% — pin the bar before the API send so the
      // footer does not sit on a stale ~70% while encrypting / posting.
      notifier.updatePendingUploadProgress(
        widget.conversationId,
        clientRef,
        1,
        parentId: reply.parentId,
      );
      if (uploadBubble!.attachments.isEmpty && body.isEmpty) {
        if (draftSend) _sendInFlight = false;
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
    if (draftSend) _sendInFlight = false;
    if (sentMsg != null) {
      unawaited(purgeSentTimedMedia(ref, attachments));
    }
    if (sentMsg != null && draftSend) {
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
      final token = CancelToken();
      final run = pickAndUploadAttachment(
        context,
        ref,
        conversationId: widget.conversationId,
        source: source,
        kind: kind,
        cancelToken: token,
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
      _uploads.track(run, cancelToken: token);
      final outcome = await run;
      // The native review screen ends on its own Send: the album and the one
      // message typed under it go out without a second trip to the composer.
      if (outcome.sendRequested && mounted) {
        if (outcome.caption.isNotEmpty) _ctrl.text = outcome.caption;
        await _send();
      }
    } catch (error) {
      _attachFailed(error);
    }
  }

  /// One place that turns an attach failure into words, for every door.
  void _attachFailed(Object error) {
    if (!mounted) return;
    if (error is GroupMediaRestrictedException) {
      final copy = groupMediaRestrictedCopy(error.kind);
      _showMessage(copy.en, copy.bn);
    } else if (error is ChatAttachmentSizeException) {
      _showMessage(
        'Files must be 350 MB or smaller.',
        'ফাইল ৩৫০ MB বা তার কম হতে হবে।',
      );
    } else {
      _showMessage('Could not attach this file.', 'ফাইল সংযুক্ত করা যায়নি।');
    }
  }

  /// A sticker or GIF the keyboard inserted (Gboard, Samsung, SwiftKey). It
  /// is sent on its own the moment it is inserted — no pending strip, no
  /// Send tap — while the upload runs behind the usual uploading bubble.
  Future<void> _attachInserted(KeyboardInsertedContent content) async {
    final picked = keyboardContentFile(content);
    if (picked == null) {
      _showMessage(
        'This keyboard item cannot be sent.',
        'কিবোর্ডের এই আইটেমটি পাঠানো যাবে না।',
      );
      return;
    }
    try {
      final token = CancelToken();
      final inserted = <ChatAttachmentInput>[];
      final run = uploadAttachments(
        ref,
        conversationId: widget.conversationId,
        sources: [pickedFileSource(picked)],
        onAdded: inserted.add,
        onFailed: _dropPending,
        onProgress: _onUploadProgress,
        onReady: () => unawaited(_send(only: inserted)),
        cancelToken: token,
      );
      _uploads.track(run, cancelToken: token);
      await run;
    } catch (error) {
      _attachFailed(error);
    }
  }

  /// Whether a group admin left any kind open that this chip can pick
  /// (server 0157): photos or videos for Gallery and Camera, files or music
  /// for File. Anything else — a DM, an older server — is open.
  bool _mediaAllowed({required bool visual}) {
    final conversation = ref
        .read(chatProvider)
        .conversationById(widget.conversationId);
    if (conversation == null) return true;
    final perms = GroupPermissions(conversation);
    return visual
        ? perms.canSendMedia(GroupMediaKind.photos) ||
              perms.canSendMedia(GroupMediaKind.videos)
        : perms.canSendMedia(GroupMediaKind.files) ||
              perms.canSendMedia(GroupMediaKind.music);
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
      final token = CancelToken();
      final run = reviewAndUploadRecentMedia(
        ref,
        conversationId: widget.conversationId,
        items: selected,
        maxSelection: _maxAttachments - _pending.length,
        initialCaption: _ctrl.text,
        cancelToken: token,
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
      _uploads.track(run, cancelToken: token);
      await run;
    } catch (error) {
      _attachFailed(error);
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

  /// Khaam is one sender, one receiver: offered in a DM with a peer, on the
  /// main timeline only.
  VoidCallback? get _khaamAction {
    if (widget.parentId != null) return null;
    final conv = ref.read(chatProvider).conversationById(widget.conversationId);
    if (conv == null || !conv.hasDmPeer) return null;
    return () {
      _closeAttachmentPanel();
      unawaited(
        openKhaamFlow(
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

  void _showMessage(String english, String bangla) {
    if (!mounted) return;
    final language = ref.read(appLanguageProvider);
    showAppToast(context, language == 'bn' ? bangla : english);
  }

  void _showMicPermissionSettings() {
    if (!mounted) return;
    final language = ref.read(appLanguageProvider);
    final isBn = language == 'bn';
    showAppToast(
      context,
      isBn
          ? 'মাইক্রোফোন বন্ধ আছে। সেটিংস থেকে অনুমতি চালু করুন।'
          : 'Microphone access is blocked. Enable it in Settings.',
      isError: true,
      actionLabel: isBn ? 'সেটিংস' : 'Settings',
      onAction: openAppSettings,
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
      selectionBadge: !_attachmentPanelOpen && _selectedRecent.isNotEmpty
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
        onContentInserted: _mediaAllowed(visual: true)
            ? (content) => unawaited(_attachInserted(content))
            : null,
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
                    onGallery: _mediaAllowed(visual: true)
                        ? () => _selectAttachment(ComposerAttachKind.gallery)
                        : null,
                    onCamera: _mediaAllowed(visual: true)
                        ? () => _selectAttachment(ComposerAttachKind.camera)
                        : null,
                    onFile: _mediaAllowed(visual: false)
                        ? () => _selectAttachment(ComposerAttachKind.file)
                        : null,
                    khaamLabel: tr('khaam_chip'),
                    onKhaam: _khaamAction,
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
                showAppToast(context, 'Message removed');
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
                showAppToast(context, 'Added $names to the channel');
              }
            },
            child: const Text('Add to group'),
          ),
        ],
      );
    },
  );
}

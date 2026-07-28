import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/localization/app_translations.dart';
import '../../../shared/media/picked_media_file.dart';
import '../../messages/chat-timeline/composer_attach.dart';
import '../../messages/chat-timeline/composer_collapsed.dart';
import '../../messages/chat-timeline/composer_expanded_shell.dart';
import '../../messages/chat-timeline/composer_slack_field.dart';
import '../../messages/chat-timeline/composer_text_actions.dart';
import '../../messages/data/models/chat_models.dart';
import '../../messages/providers/team_gate_provider.dart';
import '../../messages/tiptap_plain_text.dart';
import '../data/board_repository.dart';
import '../data/models/board_models.dart';

typedef KanbanCommentSubmit = Future<void> Function({
  required String bodyJson,
  required List<KanbanCommentAttachmentInput> attachments,
});

/// Same Slack-style input zone as chat [`MessageComposer`], wired to kanban APIs.
class KanbanCommentComposer extends ConsumerStatefulWidget {
  const KanbanCommentComposer({
    super.key,
    required this.taskId,
    required this.onSubmit,
    this.hintName = 'thread',
    this.sendLabelKey = 'chat_send',
  });

  final String taskId;
  final KanbanCommentSubmit onSubmit;
  final String hintName;
  final String sendLabelKey;

  @override
  ConsumerState<KanbanCommentComposer> createState() =>
      _KanbanCommentComposerState();
}

class _KanbanCommentComposerState extends ConsumerState<KanbanCommentComposer> {
  late final TextEditingController _ctrl;
  late final FocusNode _focus;
  final _pending = <ChatAttachmentInput>[];
  var _focused = false;
  var _forceExpanded = false;
  var _tall = false;
  var _sending = false;

  String get _hint => widget.hintName == 'thread'
      ? 'Reply in thread…'
      : 'Add a comment… (@ to mention)';
  bool get _hasDraft => _ctrl.text.trim().isNotEmpty || _pending.isNotEmpty;
  bool get _expanded => _forceExpanded || _focused || _hasDraft;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController()..addListener(() => setState(() {}));
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
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  List<KanbanCommentAttachmentInput> _toKanbanAttachments() {
    return _pending
        .map(
          (a) => KanbanCommentAttachmentInput(
            fileUrl: a.fileUrl,
            fileName: a.fileName,
            contentType: a.contentType,
            sizeBytes: a.sizeBytes,
          ),
        )
        .toList(growable: false);
  }

  Future<void> _send() async {
    final plain = _ctrl.text.trim();
    if ((plain.isEmpty && _pending.isEmpty) || _sending) return;
    setState(() => _sending = true);
    try {
      final bodyJson =
          plain.isEmpty ? textToTiptapJson('') : textToTiptapJson(plain);
      await widget.onSubmit(
        bodyJson: bodyJson,
        attachments: _toKanbanAttachments(),
      );
      if (!mounted) return;
      _ctrl.clear();
      setState(() {
        _pending.clear();
        _forceExpanded = false;
        _tall = false;
      });
      _focus.unfocus();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not send: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _attach({ImageSource? source}) async {
    final isPremium =
        ref.read(teamGateProvider).valueOrNull?.teamIsPremium == true;
    if (!isPremium) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Attachments require team premium')),
      );
      return;
    }

    ComposerAttachKind? kind;
    if (source == ImageSource.gallery) {
      kind = ComposerAttachKind.gallery;
    } else if (source == ImageSource.camera) {
      kind = ComposerAttachKind.camera;
    } else {
      kind = await showComposerAttachSheet(context);
    }
    if (kind == null) return;

    await Future<void>.delayed(const Duration(milliseconds: 280));

    try {
      final picked = switch (kind) {
        ComposerAttachKind.gallery => await pickGalleryImageFile(),
        ComposerAttachKind.camera => await pickLiveCameraFile(),
        ComposerAttachKind.file => await pickDeviceFile(),
      };
      if (picked == null || !mounted) return;

      final repo = ref.read(boardRepositoryProvider);
      final uploaded = await repo.uploadTaskAttachment(widget.taskId, picked);
      if (!mounted) return;
      setState(() {
        _pending.add(
          ChatAttachmentInput(
            fileUrl: uploaded.fileUrl,
            fileName: uploaded.fileName,
            contentType: uploaded.contentType,
            sizeBytes: uploaded.sizeBytes,
          ),
        );
        _forceExpanded = true;
      });
      _focus.requestFocus();
    } on FileSystemException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not attach: $e')),
      );
    }
  }

  String tr(String key) => AppTranslations.translate(context, ref, key);

  @override
  Widget build(BuildContext context) {
    final sendLabel = widget.sendLabelKey == 'chat_send'
        ? tr('chat_send')
        : widget.sendLabelKey;

    if (!_expanded) {
      return ComposerCollapsed(
        hint: _hint,
        onFocusTap: _openExpanded,
        onPlus: () => _attach(),
        voiceAction: const SizedBox.shrink(),
      );
    }

    return ComposerExpandedShell(
      pending: _pending,
      onRemove: (i) => setState(() => _pending.removeAt(i)),
      onAddPhoto: () => _attach(),
      field: ComposerSlackField(
        controller: _ctrl,
        focusNode: _focus,
        hint: _hint,
        sending: _sending,
        canSend: _hasDraft,
        expanded: _tall,
        isGroup: true,
        showVoice: false,
        showShareContact: false,
        onAttach: () => _attach(),
        onVoice: () {},
        onShareContact: () {},
        onMention: () => insertComposerAt(_ctrl),
        onExpand: () => setState(() => _tall = !_tall),
        onSend: _send,
        attachTooltip: tr('chat_attach'),
        voiceTooltip: tr('chat_tap_to_record'),
        shareContactTooltip: tr('chat_share_contact'),
        mentionTooltip: tr('chat_mention'),
        expandTooltip: tr('chat_expand'),
        sendLabel: sendLabel,
      ),
    );
  }
}

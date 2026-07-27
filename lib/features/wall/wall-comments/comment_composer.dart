import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../shared/media/picked_media_file.dart';
import '../../../shared/widgets/action_composer.dart';
import '../../../shared/widgets/voice_capture_action.dart';
import '../../messages/chat-timeline/composer_collapsed.dart';
import '../../messages/chat-timeline/composer_toolbar.dart';
import '../../messages/chat-timeline/voice_message_recorder.dart';
import '../../messages/providers/team_gate_provider.dart';
import '../data/models/wall_models.dart';
import '../providers/wall_provider.dart';
import '../wall-composer/attach_image.dart';
import '../wall_utils.dart';
import 'comment_expanded.dart';

enum _WallCommentPick { camera, gallery, file }

class WallCommentComposer extends ConsumerStatefulWidget {
  const WallCommentComposer({
    super.key,
    required this.postId,
    this.parentId,
    this.replyLabel,
    this.onClearReply,
    this.onSent,
  });

  final String postId;
  final String? parentId;
  final String? replyLabel;
  final VoidCallback? onClearReply;
  final VoidCallback? onSent;

  @override
  ConsumerState<WallCommentComposer> createState() =>
      _WallCommentComposerState();
}

class _WallCommentComposerState extends ConsumerState<WallCommentComposer> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  final _pending = <WallAttachmentInput>[];
  var _busy = false;
  var _tall = false;
  var _focused = false;
  var _forceExpanded = false;
  var _uploadingAttachment = false;

  bool get _hasDraft => _ctrl.text.trim().isNotEmpty || _pending.isNotEmpty;
  bool get _expanded =>
      _forceExpanded || _focused || _hasDraft || widget.parentId != null;
  bool get _isPremium =>
      ref.read(teamGateProvider).valueOrNull?.teamIsPremium == true;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_onDraftChanged);
    _focus.addListener(_onFocus);
  }

  void _onDraftChanged() {
    if (mounted) setState(() {});
  }

  void _onFocus() {
    setState(() {
      _focused = _focus.hasFocus;
      if (!_focus.hasFocus && !_hasDraft && widget.parentId == null) {
        _forceExpanded = false;
        _tall = false;
      }
    });
  }

  @override
  void didUpdateWidget(covariant WallCommentComposer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.parentId != oldWidget.parentId && widget.parentId != null) {
      setState(() => _forceExpanded = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focus.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onDraftChanged);
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final plain = _ctrl.text.trim();
    if ((plain.isEmpty && _pending.isEmpty) || _busy) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(wallProvider.notifier)
          .addComment(
            widget.postId,
            body: plain.isEmpty ? '' : wallBodyForApi(plain),
            parentId: widget.parentId,
            attachments: _pending.isEmpty ? null : List.of(_pending),
          );
      _ctrl.clear();
      widget.onClearReply?.call();
      widget.onSent?.call();
      setState(() {
        _pending.clear();
        _forceExpanded = false;
        _tall = false;
      });
      _focus.unfocus();
      ref.invalidate(wallPostProvider(widget.postId));
    } catch (error) {
      if (mounted) _showError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pick(_WallCommentPick kind) async {
    if (_uploadingAttachment) return;
    setState(() {
      _uploadingAttachment = true;
      _forceExpanded = true;
    });
    try {
      WallAttachmentInput? attachment;
      switch (kind) {
        case _WallCommentPick.camera:
          attachment = await pickWallImageAttachment(
            context,
            ref,
            isPremium: _isPremium,
            source: ImageSource.camera,
          );
          break;
        case _WallCommentPick.gallery:
          attachment = await pickWallImageAttachment(
            context,
            ref,
            isPremium: _isPremium,
            source: ImageSource.gallery,
          );
          break;
        case _WallCommentPick.file:
          attachment = await pickWallFileAttachment(
            context,
            ref,
            isPremium: _isPremium,
          );
          break;
      }
      final added = attachment;
      if (added != null && mounted) {
        setState(() => _pending.add(added));
      }
    } catch (error) {
      if (mounted) _showError(error);
    } finally {
      if (mounted) setState(() => _uploadingAttachment = false);
    }
  }

  Future<void> _pickMenu() async {
    final kind = await showModalBottomSheet<_WallCommentPick>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Camera'),
              onTap: () => Navigator.pop(sheetContext, _WallCommentPick.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Gallery'),
              onTap: () =>
                  Navigator.pop(sheetContext, _WallCommentPick.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.attach_file_rounded),
              title: const Text('Files'),
              onTap: () => Navigator.pop(sheetContext, _WallCommentPick.file),
            ),
          ],
        ),
      ),
    );
    if (kind != null && mounted) await _pick(kind);
  }

  Future<void> _sendVoice(RecordedVoiceMessage recording) async {
    if (!_isPremium) {
      throw StateError('Attachments require team premium');
    }
    final bytes = await File(recording.path).readAsBytes();
    final attachment = await uploadWallAttachment(
      ref,
      PickedMediaFile(
        bytes: Uint8List.fromList(bytes),
        fileName: recording.fileName,
        contentType: RecordedVoiceMessage.contentType,
      ),
    );
    try {
      await ref
          .read(wallProvider.notifier)
          .addComment(
            widget.postId,
            body: '',
            parentId: widget.parentId,
            attachments: [attachment],
          );
    } catch (_) {
      await ref.read(wallProvider.notifier).discardUpload(attachment.fileUrl);
      rethrow;
    }
    widget.onClearReply?.call();
    widget.onSent?.call();
    ref.invalidate(wallPostProvider(widget.postId));
  }

  void _removePending(int index) {
    final removed = _pending.removeAt(index);
    setState(() {});
    unawaited(_discardQuietly(removed.fileUrl));
  }

  Future<void> _discardQuietly(String fileUrl) async {
    try {
      await ref.read(wallProvider.notifier).discardUpload(fileUrl);
    } catch (_) {}
  }

  void _openExpanded() {
    setState(() => _forceExpanded = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  void _showError(Object error) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(error.toString())));
  }

  Widget _voiceAction() {
    return VoiceCaptureAction(
      enabled: _isPremium && !_busy && !_uploadingAttachment,
      onRecorded: _sendVoice,
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(teamGateProvider);
    if (!_expanded) {
      return ComposerCollapsed(
        hint: 'Write a comment…',
        onFocusTap: _openExpanded,
        onPlus: _pickMenu,
        voiceAction: _voiceAction(),
      );
    }
    return WallCommentExpanded(
      controller: _ctrl,
      focusNode: _focus,
      hint: widget.parentId != null ? 'Write a reply…' : 'Jot something down',
      tall: _tall,
      busy: _busy || _uploadingAttachment,
      canSend: _hasDraft,
      replyLabel: widget.replyLabel,
      onClearReply: widget.onClearReply,
      pending: _pending,
      onRemovePending: _removePending,
      onAddPhoto: () => _pick(_WallCommentPick.camera),
      actions: [
        _voiceAction(),
        ComposerActionButton(
          tooltip: 'Camera',
          icon: Icons.photo_camera_outlined,
          enabled: !_busy && !_uploadingAttachment,
          onPressed: () => _pick(_WallCommentPick.camera),
        ),
        ComposerActionButton(
          tooltip: 'Files',
          icon: Icons.attach_file_rounded,
          enabled: !_busy && !_uploadingAttachment,
          onPressed: () => _pick(_WallCommentPick.file),
        ),
        ComposerActionButton(
          tooltip: 'Emoji',
          icon: Icons.sentiment_satisfied_alt_outlined,
          onPressed: () => showEmojiPicker(context, _ctrl),
        ),
        ComposerActionButton(
          tooltip: _tall ? 'Collapse' : 'Expand',
          icon: _tall ? Icons.close_fullscreen_rounded : Icons.edit_outlined,
          onPressed: () => setState(() => _tall = !_tall),
        ),
      ],
      onSend: _send,
    );
  }
}

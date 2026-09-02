import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/media/picked_media_file.dart';
import '../../messages/chat-timeline/voice_message_recorder.dart';
import '../../messages/providers/team_gate_provider.dart';
import '../../team/data/models/team_models.dart';
import '../data/models/wall_models.dart';
import '../providers/wall_provider.dart';
import '../providers/wall_ui_provider.dart';
import 'attach_image.dart';
import 'composer_form.dart';
import 'composer_picks.dart';
import 'composer_submit.dart';
import 'composer_trigger.dart';

Future<void> showWallComposerSheet(
  BuildContext context,
  WidgetRef ref, {
  required bool isPremium,
}) async {
  final ui = ref.read(wallUiProvider.notifier);
  ui.setComposerSheetOpen(true);
  try {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => WallComposerSheet(isPremium: isPremium),
    );
  } finally {
    ui.setComposerSheetOpen(false);
  }
}

class WallComposerSheet extends ConsumerStatefulWidget {
  const WallComposerSheet({super.key, required this.isPremium});
  final bool isPremium;

  @override
  ConsumerState<WallComposerSheet> createState() => _WallComposerSheetState();
}

class _WallComposerSheetState extends ConsumerState<WallComposerSheet> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  final _mentions = <String, String>{};
  final _pending = <WallAttachmentInput>[];
  WallCategory? _category;
  ComposerTrigger? _trigger;
  var _busy = false;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_syncTrigger);
  }

  @override
  void dispose() {
    _ctrl.removeListener(_syncTrigger);
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _syncTrigger() {
    final t = detectComposerTrigger(
      _ctrl.text,
      _ctrl.selection.baseOffset.clamp(0, _ctrl.text.length),
    );
    if (t?.start != _trigger?.start ||
        t?.query != _trigger?.query ||
        t?.isMention != _trigger?.isMention) {
      setState(() => _trigger = t);
    }
  }

  Future<void> _submit() async {
    final plain = _ctrl.text.trim();
    if ((plain.isEmpty && _pending.isEmpty) || _busy) return;
    setState(() => _busy = true);
    try {
      await submitWallComposer(
        ref: ref,
        context: context,
        plain: plain,
        mentions: _mentions,
        category: _category,
        pending: _pending,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _pickMember(TeamMember m) {
    final t = _trigger;
    if (t == null || !t.isMention) return;
    applyComposerTrigger(_ctrl, t, m.displayName);
    setState(() {
      _mentions[m.displayName] = m.userId;
      _trigger = null;
    });
  }

  void _insert(String ch) {
    insertComposerChar(_ctrl, ch);
    _focus.requestFocus();
    _syncTrigger();
  }

  Future<void> _attachVoice(RecordedVoiceMessage recording) async {
    if (!widget.isPremium) {
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
    if (mounted) setState(() => _pending.add(attachment));
  }

  @override
  Widget build(BuildContext context) {
    // Keyboard (viewInsets) + system nav / home indicator (viewPadding).
    // Without the latter the Post toolbar sits under the Android nav bar.
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final navBar = MediaQuery.viewPaddingOf(context).bottom;
    final trigger = _trigger;
    final isAt = trigger?.isMention == true;
    final isHash = trigger?.isMention == false;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + keyboard + navBar),
      child: WallComposerForm(
        controller: _ctrl,
        focusNode: _focus,
        triggerIsMention: trigger?.isMention,
        showSuggestions: trigger != null,
        members: isAt
            ? filterMentionMembers(
                ref.read(teamMembersProvider),
                trigger!.query,
              )
            : const [],
        categories: isHash
            ? filterWallCategories(
                ref.read(wallProvider).categories,
                trigger!.query,
              )
            : const [],
        pending: _pending,
        busy: _busy,
        isPremium: widget.isPremium,
        onPickMember: _pickMember,
        onPickCategory: (c) {
          applyCategoryPick(_ctrl, next: c, previous: _category);
          setState(() {
            _category = c;
            _trigger = null;
          });
        },
        onRemovePending: (i) => setState(() => _pending.removeAt(i)),
        onInsertAt: () => _insert('@'),
        onInsertHash: () => _insert('#'),
        onAttached: (a) => setState(() => _pending.add(a)),
        onVoiceRecorded: _attachVoice,
        onSubmit: _submit,
        onFieldTap: _syncTrigger,
      ),
    );
  }
}

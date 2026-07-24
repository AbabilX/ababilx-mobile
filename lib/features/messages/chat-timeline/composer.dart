import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../data/models/chat_models.dart';
import '../providers/chat_provider.dart';
import '../tiptap_plain_text.dart';
import 'composer_attach.dart';
import 'composer_collapsed.dart';
import 'composer_expanded_field.dart';
import 'composer_expanded_shell.dart';
import 'composer_soon.dart';
import 'composer_text_actions.dart';
import 'composer_toolbar.dart';

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
  final _pending = <ChatAttachmentInput>[];
  bool _tall = false;
  bool _focused = false;
  bool _forceExpanded = false;

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
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final plain = _ctrl.text.trim();
    if (plain.isEmpty && _pending.isEmpty) return;
    await ref.read(chatProvider.notifier).sendMessage(
          body: plain.isEmpty ? '' : textToTiptapJson(plain),
          attachments: List.of(_pending),
          parentId: widget.parentId,
        );
    _ctrl.clear();
    setState(() {
      _pending.clear();
      _tall = false;
      _forceExpanded = false;
    });
    _focus.unfocus();
  }

  Future<void> _attach({ImageSource? source}) => pickAndUploadImage(
        context,
        ref,
        conversationId: widget.conversationId,
        source: source,
        onAdded: (a) {
          setState(() {
            _pending.add(a);
            _forceExpanded = true;
          });
          _focus.requestFocus();
        },
      );

  @override
  Widget build(BuildContext context) {
    final sending = ref.watch(chatProvider).sending;
    if (!_expanded) {
      return ComposerCollapsed(
        hint: _hint,
        onFocusTap: _openExpanded,
        onPlus: () => _attach(),
        onMic: () => showComposerSoon(context, 'Voice messages'),
      );
    }
    return ComposerExpandedShell(
      pending: _pending,
      onRemove: (i) => setState(() => _pending.removeAt(i)),
      field: ComposerExpandedField(
        controller: _ctrl,
        focusNode: _focus,
        hint: 'Jot something down',
        tall: _tall,
        onToggleTall: () => setState(() => _tall = !_tall),
        onSubmitted: _send,
      ),
      toolbar: ComposerToolbar(
        sending: sending,
        canSend: _hasDraft,
        onShortcuts: () => showComposerSoon(context, 'Shortcuts'),
        onEmoji: () =>
            showEmojiPicker(context, (e) => insertComposerEmoji(_ctrl, e)),
        onMention: () => insertComposerAt(_ctrl),
        onFormat: () => wrapComposerBold(_ctrl),
        onAttachFile: () => _attach(source: ImageSource.gallery),
        onAttachImage: () => _attach(source: ImageSource.gallery),
        onSend: _send,
      ),
    );
  }
}

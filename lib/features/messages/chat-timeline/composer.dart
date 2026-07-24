import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/chat_models.dart';
import '../providers/chat_provider.dart';
import '../tiptap_plain_text.dart';
import 'composer_attach.dart';
import 'composer_toolbar.dart';

class MessageComposer extends ConsumerStatefulWidget {
  const MessageComposer({
    super.key,
    required this.conversationId,
    this.parentId,
    this.initialText = '',
  });

  final String conversationId;
  final String? parentId;
  final String initialText;

  @override
  ConsumerState<MessageComposer> createState() => _MessageComposerState();
}

class _MessageComposerState extends ConsumerState<MessageComposer> {
  late final TextEditingController _ctrl;
  final _pending = <ChatAttachmentInput>[];

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final plain = _ctrl.text.trim();
    if (plain.isEmpty && _pending.isEmpty) return;
    final body = plain.isEmpty ? '' : textToTiptapJson(plain);
    await ref.read(chatProvider.notifier).sendMessage(
          body: body,
          attachments: List.of(_pending),
          parentId: widget.parentId,
        );
    _ctrl.clear();
    setState(() => _pending.clear());
  }

  void _wrapBold() {
    final t = _ctrl.text;
    final sel = _ctrl.selection;
    if (!sel.isValid) return;
    final inner = sel.textInside(t);
    final next = '${sel.textBefore(t)}*$inner*${sel.textAfter(t)}';
    _ctrl.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: sel.start + inner.length + 2),
    );
  }

  void _insertAt() {
    final t = _ctrl.text;
    final sel = _ctrl.selection;
    final at = sel.isValid ? sel.start : t.length;
    final next = '${t.substring(0, at)}@${t.substring(at)}';
    _ctrl.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: at + 1),
    );
  }

  void _insertEmoji(String emoji) {
    final t = _ctrl.text;
    final at = _ctrl.selection.isValid ? _ctrl.selection.start : t.length;
    final next = '${t.substring(0, at)}$emoji${t.substring(at)}';
    _ctrl.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: at + emoji.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sending = ref.watch(chatProvider).sending;
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_pending.isNotEmpty) ComposerPendingChips(
                items: _pending,
                onRemove: (i) => setState(() => _pending.removeAt(i)),
              ),
              TextField(
                controller: _ctrl,
                minLines: 1,
                maxLines: 5,
                decoration: InputDecoration(
                  hintText: 'Message…',
                  filled: true,
                  fillColor: colors.surfaceContainerHighest,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                ),
                onSubmitted: (_) => _send(),
              ),
              ComposerToolbar(
                sending: sending,
                onAttach: () => pickAndUploadImage(
                  context,
                  ref,
                  conversationId: widget.conversationId,
                  onAdded: (a) => setState(() => _pending.add(a)),
                ),
                onFormat: _wrapBold,
                onEmoji: () => showEmojiPicker(context, _insertEmoji),
                onMention: _insertAt,
                onSend: _send,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

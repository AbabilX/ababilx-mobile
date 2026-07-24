import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/wall_provider.dart';
import '../wall_utils.dart';

class WallCommentComposer extends ConsumerStatefulWidget {
  const WallCommentComposer({
    super.key,
    required this.postId,
    this.parentId,
    this.replyLabel,
    this.onClearReply,
    this.onSent,
    this.autofocus = false,
  });

  final String postId;
  final String? parentId;
  final String? replyLabel;
  final VoidCallback? onClearReply;
  final VoidCallback? onSent;
  final bool autofocus;

  @override
  ConsumerState<WallCommentComposer> createState() =>
      _WallCommentComposerState();
}

class _WallCommentComposerState extends ConsumerState<WallCommentComposer> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  var _busy = false;

  @override
  void didUpdateWidget(covariant WallCommentComposer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.parentId != oldWidget.parentId && widget.parentId != null) {
      _focus.requestFocus();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final plain = _ctrl.text.trim();
    if (plain.isEmpty || _busy) return;
    setState(() => _busy = true);
    try {
      await ref.read(wallProvider.notifier).addComment(
            widget.postId,
            body: wallBodyForApi(plain),
            parentId: widget.parentId,
          );
      _ctrl.clear();
      widget.onClearReply?.call();
      widget.onSent?.call();
      ref.invalidate(wallPostProvider(widget.postId));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.replyLabel != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Replying to ${widget.replyLabel}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: scheme.primary,
                    ),
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: widget.onClearReply,
                  icon: const Icon(Icons.close, size: 18),
                ),
              ],
            ),
          ),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _ctrl,
                focusNode: _focus,
                autofocus: widget.autofocus,
                minLines: 1,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: widget.parentId != null
                      ? 'Write a reply…'
                      : 'Write a comment…',
                  isDense: true,
                ),
              ),
            ),
            IconButton(
              onPressed: _busy ? null : _send,
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send),
            ),
          ],
        ),
      ],
    );
  }
}

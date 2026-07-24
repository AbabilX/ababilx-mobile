import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../messages/chat-timeline/composer_collapsed.dart';
import '../../messages/chat-timeline/composer_soon.dart';
import '../providers/wall_provider.dart';
import '../wall_utils.dart';
import 'comment_expanded.dart';

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
  var _busy = false;
  var _tall = false;
  var _focused = false;
  var _forceExpanded = false;

  bool get _hasDraft => _ctrl.text.trim().isNotEmpty;
  bool get _expanded =>
      _forceExpanded || _focused || _hasDraft || widget.parentId != null;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(() => setState(() {}));
    _focus.addListener(_onFocus);
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
      setState(() {
        _forceExpanded = false;
        _tall = false;
      });
      _focus.unfocus();
      ref.invalidate(wallPostProvider(widget.postId));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _openExpanded() {
    setState(() => _forceExpanded = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_expanded) {
      return ComposerCollapsed(
        hint: 'Write a comment…',
        onFocusTap: _openExpanded,
        onPlus: () => showComposerSoon(context, 'Attachments'),
        onMic: () => showComposerSoon(context, 'Voice comments'),
      );
    }
    return WallCommentExpanded(
      controller: _ctrl,
      focusNode: _focus,
      hint: widget.parentId != null ? 'Write a reply…' : 'Jot something down',
      tall: _tall,
      busy: _busy,
      canSend: _hasDraft,
      replyLabel: widget.replyLabel,
      onClearReply: widget.onClearReply,
      onToggleTall: () => setState(() => _tall = !_tall),
      onSend: _send,
    );
  }
}

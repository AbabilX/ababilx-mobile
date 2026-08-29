import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/chat_models.dart';
import '../chat_utils.dart';
import '../providers/chat_provider.dart';
import 'message_actions.dart';
import 'message_row_content.dart';
import 'thread_sheet.dart';

class MessageRow extends ConsumerStatefulWidget {
  const MessageRow({
    super.key,
    required this.message,
    required this.conversationId,
    this.clusterPosition = MessageClusterPosition.single,
    this.threadRootId,
    this.onOpenThread,
  });

  final ChatMessage message;
  final String conversationId;
  final MessageClusterPosition clusterPosition;
  final String? threadRootId;
  final VoidCallback? onOpenThread;

  @override
  ConsumerState<MessageRow> createState() => _MessageRowState();
}

class _MessageRowState extends ConsumerState<MessageRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;
  final _messageKey = GlobalKey();
  bool _actionsOpen = false;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(
      begin: 0.3,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _onRetry(BuildContext ctx) {
    final n = ref.read(chatProvider.notifier);
    n.retrySend(widget.message);
    ScaffoldMessenger.of(ctx).showSnackBar(
      const SnackBar(
        content: Text('Resending message…'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _showActions() async {
    if (widget.message.isDeleted || _actionsOpen) return;
    HapticFeedback.mediumImpact();
    setState(() => _actionsOpen = true);
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    final boundary = _messageKey.currentContext?.findRenderObject();
    if (boundary is! RenderRepaintBoundary) {
      setState(() => _actionsOpen = false);
      return;
    }
    final origin = boundary.localToGlobal(Offset.zero);
    final anchor = origin & boundary.size;
    ui.Image? snapshot;
    try {
      final ratio = MediaQuery.devicePixelRatioOf(context).clamp(1.0, 2.0);
      snapshot = await boundary.toImage(pixelRatio: ratio);
    } catch (_) {
      snapshot = null;
    }
    if (!mounted) {
      snapshot?.dispose();
      return;
    }
    await showMessageActions(
      context,
      ref,
      widget.message,
      conversationId: widget.conversationId,
      threadRootId: widget.threadRootId,
      anchor: anchor,
      snapshot: snapshot,
    );
    if (mounted) setState(() => _actionsOpen = false);
  }

  @override
  Widget build(BuildContext context) {
    final chat = ref.watch(chatProvider);

    final isOwnMessage = widget.message.userId == chat.currentUserId;
    final isSending =
        isOwnMessage && widget.message.sendStatus == MessageSendStatus.sending;
    final isFailed =
        isOwnMessage && widget.message.sendStatus == MessageSendStatus.failed;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPress: _showActions,
      onTap: isFailed
          ? () => _onRetry(context)
          : widget.threadRootId == null && !widget.message.isDeleted
          ? () =>
                openThreadSheet(context, widget.conversationId, widget.message)
          : null,
      onDoubleTap:
          widget.threadRootId == null && !isFailed && !widget.message.isDeleted
          ? () => copyMessageText(context, ref, widget.message)
          : null,
      child: RepaintBoundary(
        key: _messageKey,
        child: MessageRowContent(
          message: widget.message,
          pulse: _pulseAnim,
          isSending: isSending,
          isFailed: isFailed,
          actionsOpen: _actionsOpen,
          clusterPosition: widget.clusterPosition,
          onOpenThread: widget.onOpenThread,
        ),
      ),
    );
  }
}

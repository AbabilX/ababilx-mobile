import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../chat-select/message_selection.dart';
import '../chat-select/selectable_message_row.dart';
import '../data/models/chat_models.dart';
import '../chat_utils.dart';
import '../providers/chat_provider.dart';
import '../wallpaper/chat_wallpaper_provider.dart';
import 'message_actions.dart';
import 'message_row_content.dart';
import 'message_swipe_reply.dart';
import 'signal_menu_pointer.dart';
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
  SignalMenuPointer? _pointer;

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
    _pointer?.dispose();
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

  /// Opens the overlay on the press itself, not on release — the finger keeps
  /// the gesture, so it can carry straight on into the reaction bar.
  Future<void> _showActions(Offset touchDown) async {
    if (widget.message.isDeleted || _actionsOpen) return;
    final box = _messageKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return;
    HapticFeedback.mediumImpact();
    final anchor = box.localToGlobal(Offset.zero) & box.size;

    final pointer = SignalMenuPointer(touchDown);
    setState(() {
      _actionsOpen = true;
      _pointer = pointer;
    });
    await showMessageActions(
      context,
      ref,
      widget.message,
      conversationId: widget.conversationId,
      threadRootId: widget.threadRootId,
      anchor: anchor,
      // The message drawn again rather than photographed. See
      // [showSignalMessageMenu].
      focused: SizedBox(width: anchor.width, child: _content(focused: true)),
      pointer: pointer,
    );
    pointer.dispose();
    if (mounted) {
      setState(() {
        _actionsOpen = false;
        _pointer = null;
      });
    }
  }

  Widget _content({required bool focused}) {
    final chat = ref.watch(chatProvider);
    final conversation = chat.conversationById(widget.conversationId);
    final hasWallpaper = ref
        .watch(chatWallpaperProvider)
        .forChat(widget.conversationId)
        .isSet;
    final isOwnMessage = widget.message.userId == chat.currentUserId;
    return MessageRowContent(
      message: widget.message,
      pulse: _pulseAnim,
      isSending:
          isOwnMessage &&
          (widget.message.sendStatus == MessageSendStatus.sending ||
              widget.message.sendStatus == MessageSendStatus.uploading),
      isFailed:
          isOwnMessage && widget.message.sendStatus == MessageSendStatus.failed,
      isOwnMessage: isOwnMessage,
      clusterPosition: widget.clusterPosition,
      isGroup: conversation?.isGroupConversation ?? false,
      hasWallpaper: hasWallpaper,
      onOpenThread: focused ? null : widget.onOpenThread,
    );
  }

  @override
  Widget build(BuildContext context) {
    final chat = ref.watch(chatProvider);
    final isOwnMessage = widget.message.userId == chat.currentUserId;
    final isSending =
        isOwnMessage &&
        (widget.message.sendStatus == MessageSendStatus.sending ||
            widget.message.sendStatus == MessageSendStatus.uploading);
    final isFailed =
        isOwnMessage && widget.message.sendStatus == MessageSendStatus.failed;
    final selection = ref.watch(messageSelectionProvider);
    // Selection is a main-timeline mode; a thread panel has nowhere to put
    // its bars, so rows there never enter it.
    final selecting =
        widget.threadRootId == null &&
        selection.isActiveIn(widget.conversationId);
    final selected = selecting && selection.contains(widget.message.id);
    final hasWallpaper = ref
        .watch(chatWallpaperProvider)
        .forChat(widget.conversationId)
        .isSet;

    void toggleSelection() => ref
        .read(messageSelectionProvider.notifier)
        .toggle(
          conversationId: widget.conversationId,
          messageId: widget.message.id,
        );

    return MessageSwipeReply(
      // A deleted message has nothing to quote, and a bubble that has not
      // reached the server yet has no id to reply to. Swiping is also off
      // while selecting — Signal's `SwipeAvailabilityProvider` checks
      // `isActionModeStarted()` first, and a swipe that answers a message the
      // user is picking out is never what was meant.
      enabled:
          !selecting && !widget.message.isDeleted && !isSending && !isFailed,
      onReply: () =>
          ref.read(chatProvider.notifier).setReplyToMessage(widget.message),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        // While selecting, a press picks rows and nothing else: the overlay
        // menu would offer Select on top of an open selection.
        onLongPressStart: selecting
            ? null
            : (d) => _showActions(d.globalPosition),
        onLongPressMoveUpdate: selecting
            ? null
            : (d) => _pointer?.moveTo(d.globalPosition),
        onLongPressEnd: selecting ? null : (_) => _pointer?.release(),
        onLongPressCancel: selecting ? null : () => _pointer?.release(),
        onTap: selecting
            ? toggleSelection
            : isFailed
            ? () => _onRetry(context)
            : widget.threadRootId == null && !widget.message.isDeleted
            ? () => openThreadSheet(
                context,
                widget.conversationId,
                widget.message,
              )
            : null,
        onDoubleTap:
            !selecting &&
                widget.threadRootId == null &&
                !isFailed &&
                !widget.message.isDeleted
            ? () => copyMessageText(context, ref, widget.message)
            : null,
        child: SelectableMessageRow(
          selecting: selecting,
          selected: selected,
          hasWallpaper: hasWallpaper,
          child: KeyedSubtree(
            key: _messageKey,
            // The lifted copy is the only one on screen: Signal hides the
            // original so it does not sit under the scrim behind its own
            // double.
            child: Visibility(
              visible: !_actionsOpen,
              maintainSize: true,
              maintainAnimation: true,
              maintainState: true,
              child: _content(focused: false),
            ),
          ),
        ),
      ),
    );
  }
}

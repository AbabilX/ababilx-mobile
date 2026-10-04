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
import 'message_quick_react.dart';
import 'message_row_content.dart';
import 'message_row_gestures.dart';
import 'message_row_pulse.dart';
import 'message_swipe_reply.dart';
import 'signal_menu_pointer.dart';

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
    with SingleTickerProviderStateMixin, MessageRowPulse {
  final _messageKey = GlobalKey();
  bool _actionsOpen = false;
  SignalMenuPointer? _pointer;

  @override
  ChatMessage get pulsedMessage => widget.message;

  @override
  void dispose() {
    _pointer?.dispose();
    super.dispose();
  }

  void _open(SignalMenuPointer? p, {required bool open}) =>
      setState(() => (_actionsOpen = open, _pointer = p));

  /// Opens the overlay. From a tap there is no finger left to follow
  /// ([touchDown] null); from a hold in a thread it opens on the press itself
  /// and the finger carries straight on into the reaction bar.
  Future<void> _showActions(Offset? touchDown) async {
    if (widget.message.isDeleted || _actionsOpen) return;
    final box = _messageKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return;
    if (touchDown != null) HapticFeedback.mediumImpact();
    final anchor = box.localToGlobal(Offset.zero) & box.size;

    final pointer = touchDown == null ? null : SignalMenuPointer(touchDown);
    _open(pointer, open: true);
    void restore() {
      if (!mounted || !_actionsOpen) return;
      _open(null, open: false);
    }

    await showMessageActions(
      context,
      ref,
      widget.message,
      conversationId: widget.conversationId,
      threadRootId: widget.threadRootId,
      anchor: anchor,
      focused: SizedBox(width: anchor.width, child: _content(focused: true)),
      pointer: pointer,
      onMenuClosed: restore,
    );
    pointer?.dispose();
    restore();
  }

  Widget _content({required bool focused}) {
    final userId = ref.watch(chatProvider.select((c) => c.currentUserId));
    final isGroup = ref.watch(
      chatProvider.select(
        (c) =>
            c.conversationById(widget.conversationId)?.isGroupConversation ??
            false,
      ),
    );
    final isOwnMessage = widget.message.userId == userId;
    final status = widget.message.sendStatus;
    return MessageRowContent(
      message: widget.message,
      pulse: pulse,
      isSending:
          isOwnMessage &&
          (status == MessageSendStatus.sending ||
              status == MessageSendStatus.uploading),
      isFailed: isOwnMessage && status == MessageSendStatus.failed,
      isOwnMessage: isOwnMessage,
      clusterPosition: widget.clusterPosition,
      isGroup: isGroup,
      hasWallpaper: ref
          .watch(chatWallpaperProvider)
          .forChat(widget.conversationId)
          .isSet,
      onOpenThread: focused ? null : widget.onOpenThread,
    );
  }

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(chatProvider.select((c) => c.currentUserId));
    final isOwnMessage = widget.message.userId == userId;
    final status = widget.message.sendStatus;
    final isSending =
        isOwnMessage &&
        (status == MessageSendStatus.sending ||
            status == MessageSendStatus.uploading);
    final isFailed = isOwnMessage && status == MessageSendStatus.failed;
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

    // A deleted row cannot start a selection, only join an open one.
    final canSelect =
        widget.threadRootId == null && (selecting || !widget.message.isDeleted);

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
      child: MessageRowGestures(
        // A thread panel has no selection bars, so a hold there still opens
        // the menu, finger carried into the reaction bar as before.
        onHoldSelect: canSelect ? toggleSelection : null,
        onHoldStart: (at) => _showActions(at),
        onHoldMove: (at) => _pointer?.moveTo(at),
        onHoldEnd: () => _pointer?.release(),
        onTap: selecting
            ? toggleSelection
            : isFailed
            ? () => retryFailedMessage(context, ref, widget.message)
            : widget.message.isDeleted
            ? null
            : () => _showActions(null),
        onDoubleTap: !selecting && canQuickReact(ref, widget.message)
            ? () => quickReact(ref, widget.message)
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

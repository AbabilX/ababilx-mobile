import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/router/shell_bottom_bar/shell_pill_metrics.dart';
import '../../local_share/data/share_thread_queries.dart';
import '../../local_share/widgets/share_chat_row.dart';
import '../data/models/chat_models.dart';
import 'add_friends_reveal.dart';
import 'chat_list_entries.dart';
import 'conversation_row.dart';

class ConversationRows extends StatefulWidget {
  const ConversationRows({
    super.key,
    required this.entries,
    required this.onTap,
    required this.onShareTap,
    required this.onShareLongPress,
    required this.onRefresh,
    required this.onLongPress,
    this.currentUserId,
    this.header,
    this.hideHeaderUntilPull = false,
  });

  /// A first row above the entries (the All tab's Add new friends).
  final Widget? header;

  /// Past five chats the header stays tucked until the user scrolls up.
  final bool hideHeaderUntilPull;

  final List<ChatListEntry> entries;
  final void Function(ChatConversation) onTap;

  /// A Local Share device thread the user moved into this list.
  final void Function(ShareThread) onShareTap;
  final void Function(ShareThread) onShareLongPress;
  final Future<void> Function() onRefresh;

  /// The reference app's gesture: press and hold a row for what can be done to
  /// it.
  final void Function(ChatConversation) onLongPress;
  final String? currentUserId;

  @override
  State<ConversationRows> createState() => _ConversationRowsState();
}

class _ConversationRowsState extends State<ConversationRows> {
  final _refreshKey = GlobalKey<RefreshIndicatorState>();
  final _listKey = GlobalKey();
  final _gate = AddFriendsPullGate();
  late final ValueNotifier<double> _reveal = ValueNotifier(
    widget.hideHeaderUntilPull ? 0 : 1,
  );

  /// The pull that is opening a tucked row. Refresh waits until it goes further.
  bool _openingPull = false;
  Timer? _hideTimer;

  bool get _tuck => widget.hideHeaderUntilPull && widget.header != null;

  bool get _holdRefresh => _tuck && (!_gate.open || _openingPull);

  @override
  void didUpdateWidget(ConversationRows oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.hideHeaderUntilPull && widget.hideHeaderUntilPull) {
      _tuckAway();
    } else if (oldWidget.hideHeaderUntilPull && !widget.hideHeaderUntilPull) {
      _hideTimer?.cancel();
      _syncReveal();
    }
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _reveal.dispose();
    super.dispose();
  }

  /// Moves only the header. The chat rows stay mounted, so a pull does not
  /// rebuild the list.
  void _syncReveal() {
    final next = _tuck ? _gate.reveal : 1.0;
    if (_reveal.value == next) return;
    _reveal.value = next;
  }

  /// The row stays for five seconds after the pull that opened it, then tucks.
  void _armHide() {
    _hideTimer?.cancel();
    if (!_tuck || !_gate.open) return;
    _hideTimer = Timer(addFriendsRevealHold, () {
      if (!mounted || !_gate.open) return;
      _tuckAway();
    });
  }

  void _tuckAway() {
    _hideTimer?.cancel();
    _gate.close();
    _openingPull = false;
    _syncReveal();
  }

  double _pullDelta(ScrollNotification notification) {
    if (notification is ScrollUpdateNotification) {
      if (notification.dragDetails == null) return 0;
      final delta = notification.scrollDelta ?? 0;
      if (delta < 0 && notification.metrics.pixels <= 0) return -delta;
      return 0;
    }
    if (notification is OverscrollNotification) {
      if (notification.dragDetails == null) return 0;
      if (notification.overscroll < 0) return -notification.overscroll;
    }
    return 0;
  }

  bool _onScroll(ScrollNotification notification) {
    if (!_tuck) return false;
    if (notification is ScrollStartNotification) {
      if (notification.dragDetails != null && !_gate.open) {
        _openingPull = true;
      }
      return false;
    }
    if (notification is ScrollEndNotification) {
      final openedByThisPull = _openingPull;
      _openingPull = false;
      _gate.released();
      _syncReveal();
      if (openedByThisPull && _gate.open) _armHide();
      return false;
    }
    if (!_holdRefresh) return false;
    final delta = _pullDelta(notification);
    if (delta <= 0) return false;
    if (notification.metrics.pixels > 1 &&
        notification.metrics.extentBefore > 1) {
      return false;
    }
    final wasOpen = _gate.open;
    final refresh = _gate.dragged(
      delta,
      refreshDistance: addFriendsRefreshDistance(
        notification.metrics.viewportDimension,
      ),
    );
    if (refresh) _refreshKey.currentState?.show();
    if (!wasOpen) _syncReveal();
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final head = widget.header;
    final tuck = _tuck;
    if (widget.entries.isEmpty && head == null) {
      return RefreshIndicator(
        onRefresh: widget.onRefresh,
        child: ListView(
          children: const [
            SizedBox(height: 120),
            Center(child: Text('No conversations')),
          ],
        ),
      );
    }
    return RefreshIndicator(
      key: _refreshKey,
      onRefresh: widget.onRefresh,
      notificationPredicate: (notification) =>
          !_holdRefresh && defaultScrollNotificationPredicate(notification),
      child: NotificationListener<OverscrollIndicatorNotification>(
        onNotification: (notification) {
          if (_holdRefresh && !_gate.open) notification.disallowIndicator();
          return false;
        },
        child: NotificationListener<ScrollNotification>(
          onNotification: _onScroll,
          child: _revealList(context, head, tuck),
        ),
      ),
    );
  }

  Widget _revealList(BuildContext context, Widget? head, bool tuck) {
    final showInline = head != null && !tuck;
    final list = ListView.separated(
      key: _listKey,
      padding: EdgeInsets.only(bottom: ShellPillMetrics.contentBottom(context)),
      itemCount: widget.entries.length + (showInline ? 1 : 0),
      separatorBuilder: (_, _) => Divider(
        height: 1,
        indent: 82,
        color: Theme.of(context).colorScheme.outlineVariant,
      ),
      itemBuilder: (_, index) {
        if (showInline && index == 0) return head;
        final entry = widget.entries[showInline ? index - 1 : index];
        return switch (entry) {
          ConversationEntry(conversation: final c) => ConversationRow(
            key: ValueKey(entry.key),
            conversation: c,
            currentUserId: widget.currentUserId,
            onTap: () => widget.onTap(c),
            onLongPress: () => widget.onLongPress(c),
          ),
          ShareThreadEntry(:final thread) => ShareChatRow(
            key: ValueKey(entry.key),
            thread: thread,
            pinned: entry.pinned,
            onTap: () => widget.onShareTap(thread),
            onLongPress: () => widget.onShareLongPress(thread),
          ),
        };
      },
    );
    if (!tuck || head == null) return list;
    return _PullReveal(
      reveal: _reveal,
      header: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          head,
          Divider(
            height: 1,
            indent: 82,
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ],
      ),
      child: list,
    );
  }
}

/// Slides the already-built list down. The chat rows are not rebuilt.
class _PullReveal extends StatefulWidget {
  const _PullReveal({
    required this.reveal,
    required this.header,
    required this.child,
  });

  final ValueNotifier<double> reveal;
  final Widget header;
  final Widget child;

  @override
  State<_PullReveal> createState() => _PullRevealState();
}

class _PullRevealState extends State<_PullReveal> {
  @override
  void initState() {
    super.initState();
    widget.reveal.addListener(_onReveal);
  }

  @override
  void didUpdateWidget(_PullReveal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reveal == widget.reveal) return;
    oldWidget.reveal.removeListener(_onReveal);
    widget.reveal.addListener(_onReveal);
  }

  @override
  void dispose() {
    widget.reveal.removeListener(_onReveal);
    super.dispose();
  }

  void _onReveal() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final factor = widget.reveal.value.clamp(0.0, 1.0);
    if (factor == 0) return widget.child;
    // Expand fills the chat area. A loose stack would size itself to the
    // short header and the list would vanish into that strip.
    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.hardEdge,
      children: [
        Transform.translate(
          offset: Offset(0, factor * addFriendsRowExtent),
          child: widget.child,
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: ClipRect(
            child: Align(
              alignment: Alignment.topCenter,
              heightFactor: factor,
              child: widget.header,
            ),
          ),
        ),
      ],
    );
  }
}

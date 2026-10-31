import 'package:flutter/material.dart';

import 'timeline_jump.dart';

/// One row, as something a jump can land on: it registers its key with the
/// [TimelineJumpController] while it is built, and washes itself when a jump
/// picks it out.
///
/// The wash is the reference app's `pulseHighlight` — a message reached from
/// somewhere else has to be pointed at, or the screen simply changes and the
/// reader has to work out what moved. It reaches both screen edges for the same
/// reason the selection shade does, so the row's own gutters stay inside it.
class TimelineJumpTarget extends StatefulWidget {
  const TimelineJumpTarget({
    super.key,
    required this.messageId,
    required this.child,
  });

  final String messageId;
  final Widget child;

  @override
  State<TimelineJumpTarget> createState() => _TimelineJumpTargetState();
}

class _TimelineJumpTargetState extends State<TimelineJumpTarget> {
  final _rowKey = GlobalKey();
  TimelineJumpController? _controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = TimelineJumpScope.maybeOf(context);
    if (identical(next, _controller)) return;
    _controller?.unbind(widget.messageId, _rowKey);
    _controller = next;
    next?.bind(widget.messageId, _rowKey);
  }

  @override
  void didUpdateWidget(covariant TimelineJumpTarget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The list recycles a row onto another message as it scrolls.
    if (oldWidget.messageId == widget.messageId) return;
    _controller?.unbind(oldWidget.messageId, _rowKey);
    _controller?.bind(widget.messageId, _rowKey);
  }

  @override
  void dispose() {
    _controller?.unbind(widget.messageId, _rowKey);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final row = KeyedSubtree(key: _rowKey, child: widget.child);
    if (controller == null) return row;

    final scheme = Theme.of(context).colorScheme;
    final shade = Theme.of(context).brightness == Brightness.dark
        ? Colors.white.withValues(alpha: 0.16)
        : scheme.primary.withValues(alpha: 0.13);

    return ValueListenableBuilder<String?>(
      valueListenable: controller.highlighted,
      // The row is passed through rather than rebuilt: a highlight is a colour,
      // and every built row hears every change.
      child: row,
      builder: (context, id, child) => AnimatedContainer(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
        color: id == widget.messageId ? shade : Colors.transparent,
        child: child,
      ),
    );
  }
}

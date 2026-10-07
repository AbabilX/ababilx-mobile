import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../chat_icon.dart';
import 'selection_action_bar.dart';
import 'selection_bar.dart';
import 'selection_label_capsule.dart';

/// The bottom of Telegram's selection mode, floating where the composer was:
/// Reply on the left while one message is picked, Delete in a circle between,
/// Forward on the right.
///
/// When a second message is ticked Reply drains away, Delete slides to the
/// left edge and Forward floods the rest of the width, with a ripple running
/// through it; back at one message the three return.
class SelectionBottomBar extends ConsumerStatefulWidget {
  const SelectionBottomBar({super.key, required this.conversationId});

  final String conversationId;

  /// What the list and the jump button must clear while the bar is up.
  static const reservedHeight = SelectionCapsule.height + 16;

  @override
  ConsumerState<SelectionBottomBar> createState() => _SelectionBottomBarState();
}

class _SelectionBottomBarState extends ConsumerState<SelectionBottomBar>
    with SingleTickerProviderStateMixin {
  static const _gap = 8.0;

  /// Narrower than this a capsule cannot hold its label, so it is drawn bare.
  static const _minLabelWidth = 72.0;

  /// 0 = Reply and Forward side by side, 1 = Forward alone at full width.
  late final AnimationController _flood = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );

  /// Kept after Reply stops being offered, so it can still be drawn leaving.
  SelectionAction? _reply;
  bool _first = true;

  @override
  void dispose() {
    _flood.dispose();
    super.dispose();
  }

  void _sync(bool hasReply) {
    final target = hasReply ? 0.0 : 1.0;
    if (_first) {
      _first = false;
      _flood.value = target;
    } else if (hasReply && _flood.status != AnimationStatus.reverse) {
      if (_flood.value != 0) _flood.reverse();
    } else if (!hasReply && _flood.status != AnimationStatus.forward) {
      if (_flood.value != 1) _flood.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = selectionItems(context, ref, widget.conversationId);
    SelectionAction? of(SelectionActionKind kind) =>
        items.where((item) => item.kind == kind).firstOrNull;
    final reply = of(SelectionActionKind.reply);
    final forward = of(SelectionActionKind.forward);
    final delete = of(SelectionActionKind.delete);
    if (reply != null) _reply = reply;
    if (_reply == null && forward == null && delete == null) {
      return const SizedBox.shrink();
    }
    _sync(reply != null);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        child: LayoutBuilder(
          builder: (context, constraints) => AnimatedBuilder(
            animation: _flood,
            builder: (context, _) =>
                _row(constraints.maxWidth, reply != null, forward, delete),
          ),
        ),
      ),
    );
  }

  Widget _row(
    double width,
    bool replyLive,
    SelectionAction? forward,
    SelectionAction? delete,
  ) {
    final raw = _flood.value;
    final flooding = _flood.status == AnimationStatus.forward;
    final t = Curves.easeInOutCubic.transform(raw);
    // The circle and its gap come out of the width the two halves share.
    final taken = delete == null ? 0.0 : SelectionCapsule.height + _gap;
    final half = (width - taken - _gap) / 2;
    final replyWidth = half * (1 - t);
    final reply = _reply;

    return Row(
      children: [
        if (reply != null && replyWidth > 1)
          Opacity(
            opacity: (1 - t).clamp(0.0, 1.0),
            child: SizedBox(
              width: replyWidth,
              child: IgnorePointer(
                ignoring: !replyLive,
                child: SelectionLabelCapsule(
                  item: reply,
                  iconFirst: false,
                  bare: replyWidth < _minLabelWidth,
                ),
              ),
            ),
          ),
        SizedBox(width: _gap * (1 - t)),
        if (delete != null) ...[
          SizedBox(
            width: SelectionCapsule.height,
            child: Tooltip(
              message: delete.label,
              child: SelectionCapsule(
                onTap: delete.onPressed,
                child: Center(
                  child: ChatIcon(
                    delete.icon,
                    color: Theme.of(context).colorScheme.onSurface,
                    strokeWidth: 1.5,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: _gap),
        ],
        // With no Forward on offer the right half simply stays empty.
        Expanded(
          child: forward == null
              ? const SizedBox(height: SelectionCapsule.height)
              : Transform.scale(
                  // A swell as the capsule takes the width, settling flat.
                  scaleY: flooding ? 1 + 0.08 * math.sin(math.pi * raw) : 1,
                  child: SelectionLabelCapsule(
                    item: forward,
                    iconFirst: true,
                    ripple: flooding ? raw : null,
                  ),
                ),
        ),
      ],
    );
  }
}

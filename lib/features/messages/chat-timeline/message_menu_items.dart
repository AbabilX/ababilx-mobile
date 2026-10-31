import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import 'message_menu.dart';
import 'message_menu_geometry.dart';

class MessageMenuItem {
  const MessageMenuItem(this.action, this.icon, this.label);
  final MessageMenuAction action;
  final List<List<dynamic>> icon;
  final String label;
}

/// The reference app's own order: Reply, Forward, Save, Copy, then the rest,
/// with the destructive row last.
List<MessageMenuItem> messageMenuItems({
  required bool isMine,
  required bool showThread,
  required bool showSave,
  required bool showSelect,
  bool showPin = false,
  bool pinned = false,
  required Map<String, String> labels,
  bool showForward = true,
  bool showCopy = true,
  bool showEdit = true,
  bool showReply = true,
}) => [
  if (showReply)
    MessageMenuItem(
      MessageMenuAction.reply,
      HugeIcons.strokeRoundedReply,
      labels['reply']!,
    ),
  if (showForward)
    MessageMenuItem(
      MessageMenuAction.forward,
      HugeIcons.strokeRoundedArrowTurnForward,
      labels['forward']!,
    ),
  if (showSave)
    MessageMenuItem(
      MessageMenuAction.save,
      HugeIcons.strokeRoundedDownload02,
      labels['save']!,
    ),
  if (showCopy)
    MessageMenuItem(
      MessageMenuAction.copy,
      HugeIcons.strokeRoundedCopy01,
      labels['copy']!,
    ),
  if (showThread)
    MessageMenuItem(
      MessageMenuAction.thread,
      HugeIcons.strokeRoundedThread,
      labels['thread']!,
    ),
  // The reference app puts multi-select right after the per-message actions and
  // before the ones that open another screen — it is the door out of this menu
  // into the selection bars, not an action on this message.
  if (showSelect)
    MessageMenuItem(
      MessageMenuAction.select,
      HugeIcons.strokeRoundedCheckmarkCircle02,
      labels['select']!,
    ),
  if (isMine && showEdit)
    MessageMenuItem(
      MessageMenuAction.edit,
      HugeIcons.strokeRoundedPencilEdit02,
      labels['edit']!,
    ),
  if (showPin)
    MessageMenuItem(
      MessageMenuAction.pin,
      pinned ? HugeIcons.strokeRoundedPinOff : HugeIcons.strokeRoundedPin,
      labels[pinned ? 'unpin' : 'pin']!,
    ),
  // Every message: somebody else's can still be deleted for me.
  MessageMenuItem(
    MessageMenuAction.delete,
    HugeIcons.strokeRoundedDelete02,
    labels['delete']!,
  ),
];

/// The panel is `wrap_content` with a 200dp floor in the reference app, so the
/// width has to be measured from the labels rather than guessed — a long
/// translation must not wrap or ellipsise.
Size messageMenuSize(
  List<MessageMenuItem> items,
  TextStyle style,
  double textScale,
  double maxWidth,
) {
  var widest = 0.0;
  for (final item in items) {
    final painter = TextPainter(
      text: TextSpan(text: item.label, style: style),
      textDirection: TextDirection.ltr,
      textScaler: TextScaler.linear(textScale),
    )..layout();
    widest = widest > painter.width ? widest : painter.width;
  }
  final width =
      (widest +
              MessageMenuMetrics.menuRowPadding * 2 +
              MessageMenuMetrics.menuIconSize +
              MessageMenuMetrics.menuIconGap)
          .clamp(MessageMenuMetrics.menuMinWidth, maxWidth);
  final rowHeight =
      MessageMenuMetrics.menuRowHeight * (textScale > 1 ? textScale : 1);
  return Size(width, rowHeight * items.length);
}

import 'package:flutter/material.dart';

import 'signal_message_menu.dart';
import 'signal_message_menu_geometry.dart';

class SignalMenuItem {
  const SignalMenuItem(this.action, this.icon, this.label);
  final SignalMessageAction action;
  final IconData icon;
  final String label;
}

/// Signal's own order: Reply, Forward, Save, Copy, then the rest, with the
/// destructive row last.
List<SignalMenuItem> signalMenuItems({
  required bool isMine,
  required bool showThread,
  required bool showSave,
  required bool showSelect,
  required Map<String, String> labels,
}) => [
  SignalMenuItem(
    SignalMessageAction.reply,
    Icons.reply_rounded,
    labels['reply']!,
  ),
  SignalMenuItem(
    SignalMessageAction.forward,
    Icons.shortcut_rounded,
    labels['forward']!,
  ),
  if (showSave)
    SignalMenuItem(
      SignalMessageAction.save,
      Icons.save_alt_rounded,
      labels['save']!,
    ),
  SignalMenuItem(
    SignalMessageAction.copy,
    Icons.content_copy_outlined,
    labels['copy']!,
  ),
  if (showThread)
    SignalMenuItem(
      SignalMessageAction.thread,
      Icons.forum_outlined,
      labels['thread']!,
    ),
  // Signal puts multi-select right after the per-message actions and before
  // the ones that open another screen — it is the door out of this menu into
  // the selection bars, not an action on this message.
  if (showSelect)
    SignalMenuItem(
      SignalMessageAction.select,
      Icons.check_circle_outline,
      labels['select']!,
    ),
  if (isMine)
    SignalMenuItem(
      SignalMessageAction.edit,
      Icons.edit_outlined,
      labels['edit']!,
    ),
  // Every message: somebody else's can still be deleted for me.
  SignalMenuItem(
    SignalMessageAction.delete,
    Icons.delete_outline_rounded,
    labels['delete']!,
  ),
];

/// The panel is `wrap_content` with a 200dp floor in Signal, so the width has
/// to be measured from the labels rather than guessed — a long translation must
/// not wrap or ellipsise.
Size signalMenuSize(
  List<SignalMenuItem> items,
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
              SignalMenuMetrics.menuRowPadding * 2 +
              SignalMenuMetrics.menuIconSize +
              SignalMenuMetrics.menuIconGap)
          .clamp(SignalMenuMetrics.menuMinWidth, maxWidth);
  final rowHeight =
      SignalMenuMetrics.menuRowHeight * (textScale > 1 ? textScale : 1);
  return Size(width, rowHeight * items.length);
}

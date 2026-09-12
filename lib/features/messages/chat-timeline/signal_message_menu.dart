import 'package:flutter/material.dart';

import 'signal_menu_pointer.dart';
import 'signal_message_menu_geometry.dart';
import 'signal_message_menu_items.dart';
import 'signal_message_menu_surface.dart';

enum SignalMessageAction {
  reply,
  forward,
  save,
  copy,
  thread,
  select,
  edit,
  delete,
}

sealed class SignalMessageMenuResult {
  const SignalMessageMenuResult();
}

class SignalMessageReaction extends SignalMessageMenuResult {
  const SignalMessageReaction(this.emoji);
  final String emoji;
}

class SignalMessageCommand extends SignalMessageMenuResult {
  const SignalMessageCommand(this.action);
  final SignalMessageAction action;
}

/// Signal's long-press overlay: the message lifted out of the list over a
/// scrim, its reaction bar above and the action menu below.
///
/// [focused] is the message rendered again, not a bitmap of it. Snapshotting
/// cost a ~900ms frame on a mid-range phone and put a `ui.Image` lifetime in
/// the middle of a route transition — the route's future completes on pop,
/// while the exit animation is still painting, so disposing there threw
/// "Cannot clone a disposed image" on every frame until the route left.
Future<SignalMessageMenuResult?> showSignalMessageMenu({
  required BuildContext context,
  required Rect anchor,
  required Widget focused,
  required bool isMine,
  required bool showThread,
  required bool showSave,
  required bool showSelect,
  required Map<String, String> labels,
  SignalMenuPointer? pointer,
}) {
  return showGeneralDialog<SignalMessageMenuResult>(
    context: context,
    barrierDismissible: true,
    barrierLabel: labels['dismiss'],
    barrierColor: Theme.of(context).colorScheme.scrim.withValues(alpha: 0.56),
    transitionDuration: SignalMenuMetrics.revealDuration,
    pageBuilder: (ctx, animation, _) => SignalMessageMenuSurface(
      animation: animation,
      anchor: anchor,
      focused: focused,
      isMine: isMine,
      pointer: pointer,
      items: signalMenuItems(
        isMine: isMine,
        showThread: showThread,
        showSave: showSave,
        showSelect: showSelect,
        labels: labels,
      ),
      moreLabel: labels['moreReactions']!,
    ),
  );
}

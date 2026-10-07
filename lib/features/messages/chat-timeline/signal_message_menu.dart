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
  pin,
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
  bool showPin = false,
  bool pinned = false,
  required Map<String, String> labels,
  SignalMenuPointer? pointer,
  bool showForward = true,
  bool showCopy = true,
  bool showEdit = true,
  // Off for a group member an admin made read-only (server 0157): replying
  // and reacting are both sending.
  bool showReply = true,
  bool showReactions = true,
  // Runs once the hide animation has finished — the moment the lifted copy
  // is gone and the row underneath may show itself again.
  VoidCallback? onHidden,
}) {
  // [anchor] is in screen coordinates, but the dialog is laid out inside the
  // root navigator — which the in-call return bar pushes down by its own
  // height. Measured in the screen's frame, the whole menu sat that much too
  // low and the last rows of a message near the bottom fell off the screen.
  final navigator = Navigator.of(context, rootNavigator: true);
  final box = navigator.context.findRenderObject();
  final origin = box is RenderBox && box.hasSize
      ? box.localToGlobal(Offset.zero)
      : Offset.zero;
  final route = _SignalMenuRoute(
    barrierLabel: labels['dismiss'],
    pageBuilder: (ctx, animation, _) => SignalMessageMenuSurface(
      animation: animation,
      anchor: anchor.shift(-origin),
      origin: origin,
      focused: focused,
      isMine: isMine,
      pointer: pointer,
      showReactions: showReactions,
      items: signalMenuItems(
        isMine: isMine,
        showThread: showThread,
        showSave: showSave,
        showSelect: showSelect,
        showPin: showPin,
        pinned: pinned,
        labels: labels,
        showForward: showForward,
        showCopy: showCopy,
        showEdit: showEdit,
        showReply: showReply,
      ),
      moreLabel: labels['moreReactions']!,
    ),
  );
  // `completed` is the end of the hide, `push` only the start of it.
  if (onHidden != null) route.completed.whenComplete(onHidden);
  return navigator.push(route);
}

/// A dialog route with Signal's two clocks: the staggered reveal on the way
/// in, a flat 150ms on the way out. It draws no barrier colour and no fade of
/// its own — the surface paints the shade, which Signal shows at full strength
/// from the first frame and only fades when hiding.
class _SignalMenuRoute extends RawDialogRoute<SignalMessageMenuResult> {
  _SignalMenuRoute({required super.pageBuilder, super.barrierLabel})
    : super(
        barrierDismissible: true,
        barrierColor: const Color(0x00000000),
        transitionDuration: SignalMenuMetrics.revealTotal,
        transitionBuilder: (_, _, _, child) => child,
      );

  @override
  Duration get reverseTransitionDuration => SignalMenuMetrics.hideDuration;
}

import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'signal_message_menu_panels.dart';

enum SignalMessageAction { reply, forward, save, copy, thread, edit, delete }

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

Future<SignalMessageMenuResult?> showSignalMessageMenu({
  required BuildContext context,
  required Rect anchor,
  required ui.Image? snapshot,
  required bool isMine,
  required bool showThread,
  required bool showSave,
  required Map<String, String> labels,
}) {
  return showGeneralDialog<SignalMessageMenuResult>(
    context: context,
    barrierDismissible: true,
    barrierLabel: labels['dismiss'],
    barrierColor: Theme.of(context).colorScheme.scrim.withValues(alpha: 0.56),
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (ctx, _, _) => _SignalMessageMenu(
      anchor: anchor,
      snapshot: snapshot,
      isMine: isMine,
      showThread: showThread,
      showSave: showSave,
      labels: labels,
    ),
    transitionBuilder: (_, animation, _, child) => FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
      child: child,
    ),
  );
}

class _SignalMessageMenu extends StatelessWidget {
  const _SignalMessageMenu({
    required this.anchor,
    required this.snapshot,
    required this.isMine,
    required this.showThread,
    required this.showSave,
    required this.labels,
  });

  final Rect anchor;
  final ui.Image? snapshot;
  final bool isMine;
  final bool showThread;
  final bool showSave;
  final Map<String, String> labels;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final safeTop = media.padding.top + 8;
    final safeBottom = media.size.height - media.padding.bottom - 8;
    final menuWidth = media.size.width.clamp(280.0, 340.0);
    final left = isMine
        ? (media.size.width - menuWidth - 12)
        : anchor.left.clamp(12.0, media.size.width - menuWidth - 12);
    final reactionTop = (anchor.top - 58).clamp(safeTop, safeBottom - 52);
    final desiredMenuTop = anchor.bottom + 8;
    final menuHeight = _menuHeight;
    final menuTop = desiredMenuTop + menuHeight <= safeBottom
        ? desiredMenuTop
        : (anchor.top - menuHeight - 66).clamp(safeTop + 56, safeBottom);

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.pop(context),
            ),
          ),
          if (snapshot != null)
            Positioned.fromRect(
              rect: anchor,
              child: IgnorePointer(child: _FocusedMessage(snapshot: snapshot!)),
            ),
          Positioned(
            left: left,
            top: reactionTop,
            width: menuWidth,
            child: SignalReactionBar(moreLabel: labels['moreReactions']!),
          ),
          Positioned(
            left: left,
            top: menuTop,
            width: menuWidth,
            child: SignalActionPanel(
              isMine: isMine,
              showThread: showThread,
              showSave: showSave,
              labels: labels,
            ),
          ),
        ],
      ),
    );
  }

  double get _menuHeight {
    final count =
        3 + (showSave ? 1 : 0) + (showThread ? 1 : 0) + (isMine ? 2 : 0);
    return count * 48.0 + 16;
  }
}

class _FocusedMessage extends StatelessWidget {
  const _FocusedMessage({required this.snapshot});
  final ui.Image snapshot;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(blurRadius: 14, color: Colors.black26)],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: RawImage(image: snapshot, fit: BoxFit.fill),
      ),
    );
  }
}

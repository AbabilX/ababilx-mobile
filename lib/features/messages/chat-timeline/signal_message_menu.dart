import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'signal_message_menu_geometry.dart';
import 'signal_message_menu_items.dart';
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
    transitionDuration: SignalMenuMetrics.revealDuration,
    pageBuilder: (ctx, animation, _) => _SignalMessageMenu(
      animation: animation,
      anchor: anchor,
      snapshot: snapshot,
      isMine: isMine,
      items: signalMenuItems(
        isMine: isMine,
        showThread: showThread,
        showSave: showSave,
        labels: labels,
      ),
      moreLabel: labels['moreReactions']!,
    ),
  );
}

class _SignalMessageMenu extends StatelessWidget {
  const _SignalMessageMenu({
    required this.animation,
    required this.anchor,
    required this.snapshot,
    required this.isMine,
    required this.items,
    required this.moreLabel,
  });

  final Animation<double> animation;
  final Rect anchor;
  final ui.Image? snapshot;
  final bool isMine;
  final List<SignalMenuItem> items;
  final String moreLabel;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final theme = Theme.of(context);
    final menuSize = signalMenuSize(
      items,
      theme.textTheme.bodyLarge ?? const TextStyle(fontSize: 16),
      media.textScaler.scale(1),
      media.size.width - SignalMenuMetrics.horizontalMargin * 2,
    );
    final layout = resolveSignalMenuLayout(
      screen: media.size,
      safeArea: media.padding,
      anchor: anchor,
      menuSize: menuSize,
      isMine: isMine,
    );
    final ordered = layout.reversed ? items.reversed.toList() : items;
    final move = CurvedAnimation(parent: animation, curve: Curves.decelerate);

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
            AnimatedBuilder(
              animation: move,
              builder: (context, _) => Positioned.fromRect(
                // The bubble slides from where it sits in the thread to where
                // the overlay needs it, exactly as Signal animates x/y/scale.
                rect: Rect.lerp(anchor, layout.bubble, move.value)!,
                child: IgnorePointer(
                  child: _FocusedMessage(snapshot: snapshot!),
                ),
              ),
            ),
          Positioned.fromRect(
            rect: layout.bar,
            child: SignalReactionBar(
              moreLabel: moreLabel,
              animation: animation,
            ),
          ),
          Positioned.fromRect(
            rect: layout.menu,
            child: FadeTransition(
              opacity: animation,
              child: ScaleTransition(
                scale: Tween(begin: 0.9, end: 1.0).animate(move),
                alignment: layout.reversed
                    ? (isMine ? Alignment.bottomRight : Alignment.bottomLeft)
                    : (isMine ? Alignment.topRight : Alignment.topLeft),
                child: SingleChildScrollView(
                  child: SignalActionPanel(items: ordered),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FocusedMessage extends StatelessWidget {
  const _FocusedMessage({required this.snapshot});
  final ui.Image snapshot;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: RawImage(image: snapshot, fit: BoxFit.fill),
    );
  }
}

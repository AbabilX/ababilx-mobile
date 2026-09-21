import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'signal_menu_pointer.dart';
import 'signal_message_menu.dart';
import 'signal_message_menu_backdrop.dart';
import 'signal_message_menu_focus.dart';
import 'signal_message_menu_geometry.dart';
import 'signal_message_menu_items.dart';
import 'signal_action_panel.dart';
import 'signal_message_menu_panels.dart';
import 'signal_reaction_scrub.dart';

/// The overlay itself. Stateful because it tracks the finger that opened it.
class SignalMessageMenuSurface extends StatefulWidget {
  const SignalMessageMenuSurface({
    super.key,
    required this.animation,
    required this.anchor,
    this.origin = Offset.zero,
    required this.focused,
    required this.isMine,
    required this.items,
    required this.moreLabel,
    this.pointer,
  });

  final Animation<double> animation;

  /// In the surface's own frame.
  final Rect anchor;

  /// Where the surface's top-left sits on the screen. The finger is tracked in
  /// screen coordinates, so the reaction bar is compared there.
  final Offset origin;
  final Widget focused;
  final bool isMine;
  final List<SignalMenuItem> items;
  final String moreLabel;
  final SignalMenuPointer? pointer;

  @override
  State<SignalMessageMenuSurface> createState() =>
      _SignalMessageMenuSurfaceState();
}

class _SignalMessageMenuSurfaceState extends State<SignalMessageMenuSurface> {
  int? _selected;
  Rect _bar = Rect.zero;

  @override
  void initState() {
    super.initState();
    widget.pointer?.position.addListener(_onPointerMoved);
    widget.pointer?.released.addListener(_onPointerReleased);
  }

  @override
  void dispose() {
    widget.pointer?.position.removeListener(_onPointerMoved);
    widget.pointer?.released.removeListener(_onPointerReleased);
    super.dispose();
  }

  void _onPointerMoved() {
    final pointer = widget.pointer;
    if (pointer == null || !mounted) return;
    final next = signalScrubSelection(
      bar: _bar,
      slots: SignalReactionBar.emojis.length + 1,
      pointer: pointer.position.value,
      touchDown: pointer.touchDown,
    );
    if (next == _selected) return;
    // Signal ticks once per emoji entered, never on leaving one.
    if (next != null) HapticFeedback.selectionClick();
    setState(() => _selected = next);
  }

  /// A release over an emoji reacts. A release anywhere else leaves the menu
  /// open — that is the ordinary long-press-and-let-go, and closing there would
  /// make the menu unreachable.
  void _onPointerReleased() {
    if (!mounted || widget.pointer?.released.value != true) return;
    final index = _selected;
    if (index == null) return;
    final emojis = SignalReactionBar.emojis;
    Navigator.pop(
      context,
      SignalMessageReaction(index < emojis.length ? emojis[index] : ''),
    );
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => _build(context, constraints.biggest),
  );

  Widget _build(BuildContext context, Size screen) {
    final media = MediaQuery.of(context);
    final theme = Theme.of(context);
    final menuSize = signalMenuSize(
      widget.items,
      theme.textTheme.bodyLarge ?? const TextStyle(fontSize: 16),
      media.textScaler.scale(1),
      screen.width - SignalMenuMetrics.horizontalMargin * 2,
    );
    final layout = resolveSignalMenuLayout(
      screen: screen,
      safeArea: media.padding,
      anchor: widget.anchor,
      menuSize: menuSize,
      isMine: widget.isMine,
    );
    _bar = layout.bar.shift(widget.origin);
    final ordered = layout.reversed
        ? widget.items.reversed.toList()
        : widget.items;
    final move = CurvedAnimation(
      parent: widget.animation,
      curve: Curves.decelerate,
    );

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.pop(context),
              child: SignalMenuBackdrop(animation: move),
            ),
          ),
          SignalFocusedMessage(
            move: move,
            anchor: widget.anchor,
            target: layout.bubble,
            targetScale: layout.scale,
            isMine: widget.isMine,
            child: widget.focused,
          ),
          Positioned.fromRect(
            rect: layout.bar,
            child: SignalReactionBar(
              moreLabel: widget.moreLabel,
              animation: widget.animation,
              selectedIndex: _selected,
            ),
          ),
          Positioned.fromRect(
            rect: layout.menu,
            child: FadeTransition(
              opacity: widget.animation,
              child: ScaleTransition(
                scale: Tween(begin: 0.9, end: 1.0).animate(move),
                alignment: layout.reversed
                    ? (widget.isMine
                          ? Alignment.bottomRight
                          : Alignment.bottomLeft)
                    : (widget.isMine ? Alignment.topRight : Alignment.topLeft),
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

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'message_menu_pointer.dart';
import 'message_menu.dart';
import 'message_menu_focus.dart';
import 'message_menu_geometry.dart';
import 'message_menu_items.dart';
import 'message_action_panel.dart';
import 'message_menu_shade.dart';
import 'message_menu_timeline.dart';
import 'message_menu_panels.dart';
import 'reaction_scrub.dart';

/// The overlay itself. Stateful because it tracks the finger that opened it.
class MessageMenuSurface extends StatefulWidget {
  const MessageMenuSurface({
    super.key,
    required this.animation,
    required this.anchor,
    this.origin = Offset.zero,
    required this.focused,
    required this.isMine,
    required this.items,
    required this.moreLabel,
    this.showReactions = true,
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
  final List<MessageMenuItem> items;
  final String moreLabel;

  /// False draws no reaction bar and ignores the press-and-slide scrub.
  final bool showReactions;
  final MessageMenuPointer? pointer;

  @override
  State<MessageMenuSurface> createState() => _MessageMenuSurfaceState();
}

class _MessageMenuSurfaceState extends State<MessageMenuSurface> {
  int? _selected;
  Rect _bar = Rect.zero;

  // Built once: a CurvedAnimation listens to its parent until disposed.
  late final CurvedAnimation _move = menuReveal(
    widget.animation,
    // ViewPropertyAnimator's default, which carries the reference app's
    // snapshot.
    curve: Curves.easeInOutSine,
  );
  late final CurvedAnimation _menu = menuReveal(widget.animation);
  late final CurvedAnimation _strip = menuReveal(
    widget.animation,
    delay: MessageMenuMetrics.revealOffset,
  );
  late final List<CurvedAnimation> _slots = [
    for (var i = 0; i <= MessageReactionBar.emojis.length; i++)
      emojiReveal(widget.animation, i),
  ];

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
    for (final a in [_move, _menu, _strip, ..._slots]) {
      a.dispose();
    }
    super.dispose();
  }

  void _onPointerMoved() {
    final pointer = widget.pointer;
    if (pointer == null || !mounted || !widget.showReactions) return;
    final next = reactionScrubSelection(
      bar: _bar,
      slots: MessageReactionBar.emojis.length + 1,
      pointer: pointer.position.value,
      touchDown: pointer.touchDown,
    );
    if (next == _selected) return;
    // The reference app ticks once per emoji entered, never on leaving one.
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
    final emojis = MessageReactionBar.emojis;
    Navigator.pop(
      context,
      MessageMenuReaction(index < emojis.length ? emojis[index] : ''),
    );
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => _build(context, constraints.biggest),
  );

  Widget _build(BuildContext context, Size screen) {
    final media = MediaQuery.of(context);
    final theme = Theme.of(context);
    final menuSize = messageMenuSize(
      widget.items,
      theme.textTheme.bodyLarge ?? const TextStyle(fontSize: 16),
      media.textScaler.scale(1),
      screen.width - MessageMenuMetrics.horizontalMargin * 2,
    );
    final layout = resolveMessageMenuLayout(
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
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.pop(context),
              child: MessageMenuShade(route: widget.animation, fadeOut: _menu),
            ),
          ),
          FocusedMessage(
            move: _move,
            anchor: widget.anchor,
            target: layout.bubble,
            targetScale: layout.scale,
            isMine: widget.isMine,
            child: widget.focused,
          ),
          if (widget.showReactions)
            Positioned.fromRect(
              rect: layout.bar,
              child: MessageReactionBar(
                moreLabel: widget.moreLabel,
                strip: _strip,
                slots: _slots,
                selectedIndex: _selected,
              ),
            ),
          Positioned.fromRect(
            rect: layout.menu,
            child: FadeTransition(
              opacity: _menu,
              child: ScaleTransition(
                scale: Tween(begin: 0.9, end: 1.0).animate(_menu),
                alignment: layout.reversed
                    ? (widget.isMine
                          ? Alignment.bottomRight
                          : Alignment.bottomLeft)
                    : (widget.isMine ? Alignment.topRight : Alignment.topLeft),
                child: SingleChildScrollView(
                  child: MessageActionPanel(items: ordered),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

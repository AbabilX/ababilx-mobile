import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'nav_reorder_blur.dart';
import 'nav_tab_item.dart';
import 'shell_pill_metrics.dart';
import 'shell_tabs.dart';

/// The capsule's tabs and its sliding chosen-tab background.
///
/// With [onReorder] a tab can be held and slid along the bar: the held tab
/// follows the finger, the others glide aside into the slot it leaves, and the
/// chosen-tab background goes with whichever tab is chosen. A quick tap or
/// swipe is left to the tab and the pager — the long press only wins when the
/// finger has stayed down without moving.
class NavTabsLayer extends StatefulWidget {
  const NavTabsLayer({
    super.key,
    required this.tabs,
    required this.slot,
    required this.pos,
    required this.labelOf,
    required this.onSelect,
    required this.unread,
    this.onReorder,
  });

  final List<ShellTab> tabs;

  /// Width of one tab.
  final double slot;

  /// The pager's position, in tabs: fractional mid-swipe.
  final double pos;
  final String Function(ShellTab tab) labelOf;
  final ValueChanged<int> onSelect;
  final int unread;
  final void Function(int from, int to)? onReorder;

  @override
  State<NavTabsLayer> createState() => _NavTabsLayerState();
}

class _NavTabsLayerState extends State<NavTabsLayer> {
  static const _glide = Duration(milliseconds: 220);

  String? _held;
  double _fingerX = 0;

  /// True just after a reorder, so the chosen-tab background glides to its new
  /// slot. Outside that it must follow the pager exactly (a swipe's finger).
  bool _gliding = false;
  Timer? _glideTimer;

  double get _maxLeft => (widget.tabs.length - 1) * widget.slot;

  int _at(double dx) =>
      (dx / widget.slot).floor().clamp(0, widget.tabs.length - 1).toInt();

  void _glideNow() {
    _gliding = true;
    _glideTimer?.cancel();
    _glideTimer = Timer(_glide + const Duration(milliseconds: 60), () {
      if (mounted) setState(() => _gliding = false);
    });
  }

  void _start(LongPressStartDetails d) {
    final reorder = widget.onReorder;
    if (reorder == null) return;
    setState(() {
      _held = widget.tabs[_at(d.localPosition.dx)].route;
      _fingerX = d.localPosition.dx;
    });
    navReordering.value = true;
    HapticFeedback.mediumImpact();
  }

  void _move(LongPressMoveUpdateDetails d) {
    final held = _held;
    final reorder = widget.onReorder;
    if (held == null || reorder == null) return;
    final from = widget.tabs.indexWhere((t) => t.route == held);
    final to = _at(d.localPosition.dx);
    setState(() => _fingerX = d.localPosition.dx);
    if (from < 0 || to == from) return;
    _glideNow();
    reorder(from, to);
    HapticFeedback.selectionClick();
  }

  void _end() {
    navReordering.value = false;
    if (_held == null) return;
    _glideNow();
    setState(() => _held = null);
  }

  @override
  void dispose() {
    navReordering.value = false;
    _glideTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tabs = widget.tabs;
    final slot = widget.slot;
    final current = widget.pos.round();
    final heldIndex = tabs.indexWhere((t) => t.route == _held);
    final heldLeft = (_fingerX - slot / 2).clamp(0.0, _maxLeft).toDouble();
    // The background rides the held tab when that tab is the chosen one.
    final followFinger = heldIndex >= 0 && heldIndex == current;
    final indicatorLeft = followFinger ? heldLeft : widget.pos * slot;
    final radius = BorderRadius.circular(
      ShellPillMetrics.height / 2 - NavTabItem.gap,
    );

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onLongPressStart: _start,
      onLongPressMoveUpdate: _move,
      onLongPressEnd: (_) => _end(),
      onLongPressCancel: _end,
      child: Stack(
        children: [
          AnimatedPositioned(
            duration: _gliding && !followFinger ? _glide : Duration.zero,
            curve: Curves.easeOutCubic,
            left: indicatorLeft + NavTabItem.gap,
            top: NavTabItem.gap,
            width: slot - NavTabItem.gap * 2,
            height: ShellPillMetrics.height - NavTabItem.gap * 2,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHigh,
                borderRadius: radius,
              ),
            ),
          ),
          for (var i = 0; i < tabs.length; i++)
            AnimatedPositioned(
              // Keyed by route so a tab keeps its state while it moves.
              key: ValueKey(tabs[i].route),
              duration: i == heldIndex ? Duration.zero : _glide,
              curve: Curves.easeOutCubic,
              left: i == heldIndex ? heldLeft : i * slot,
              top: 0,
              width: slot,
              height: ShellPillMetrics.height,
              child: Transform.scale(
                scale: i == heldIndex ? 1.06 : 1,
                child: Row(
                  children: [
                    NavTabItem(
                      icon: tabs[i].icon,
                      selectedIcon: tabs[i].selectedIcon,
                      label: widget.labelOf(tabs[i]),
                      selected: current == i,
                      badgeCount: tabs[i].showsUnread ? widget.unread : 0,
                      onTap: () => widget.onSelect(i),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

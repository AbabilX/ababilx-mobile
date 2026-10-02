import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../home_tab_position.dart';
import 'nav_tab_item.dart';
import 'shell_pill_metrics.dart';
import 'shell_tabs.dart';

/// Capsule navigation destinations, rendered from whatever [tabs] the account
/// actually has — Messages | Calls.
class NavPill extends StatelessWidget {
  const NavPill({
    super.key,
    required this.tabs,
    required this.selectedIndex,
    required this.onSelect,
    required this.labelOf,
    this.unread = 0,
  });

  final List<ShellTab> tabs;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  /// Resolves a tab's translated label — the shell owns the localisation
  /// context, this widget stays a dumb renderer.
  final String Function(ShellTab tab) labelOf;

  final int unread;

  static const double height = ShellPillMetrics.height;

  /// Room each tab asks for. The bar is as wide as its tabs want, so an
  /// account with fewer destinations gets a narrower capsule; on a small
  /// screen the bar stops at the available width and the tabs share it.
  static const double tabWidth = 84;

  /// Floor for the capsule, so two tabs do not shrink it to a sliver.
  static const double minWidth = 240;

  /// Width the capsule asks for with [count] tabs.
  static double widthFor(int count) => math.max(minWidth, count * tabWidth);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(height / 2 - NavTabItem.gap);
    return SizedBox(
      height: height,
      child: ValueListenableBuilder<double?>(
        valueListenable: homeTabPosition,
        builder: (context, position, _) {
          // The pager's own position while it has one, so the chosen-tab
          // background travels with a swipe and a tap's slide; the route's
          // index before that.
          final pos = (position ?? selectedIndex.toDouble()).clamp(
            0.0,
            (tabs.length - 1).toDouble(),
          );
          final current = pos.round();
          return LayoutBuilder(
            builder: (context, box) {
              final slot = box.maxWidth / tabs.length;
              return _BarDrag(
                slot: slot,
                child: Stack(
                  children: [
                    Positioned(
                      left: pos * slot + NavTabItem.gap,
                      top: NavTabItem.gap,
                      width: slot - NavTabItem.gap * 2,
                      height: height - NavTabItem.gap * 2,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHigh,
                          borderRadius: radius,
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        for (var i = 0; i < tabs.length; i++)
                          NavTabItem(
                            icon: tabs[i].icon,
                            selectedIcon: tabs[i].selectedIcon,
                            label: labelOf(tabs[i]),
                            selected: current == i,
                            badgeCount: tabs[i].showsUnread ? unread : 0,
                            onTap: () => onSelect(i),
                          ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// A horizontal drag on the bar moves the pages, as a swipe on the pages does.
///
/// The chosen tab's background follows the finger, as on iOS: drag right and
/// it travels right onto the next tab, the pages sliding in behind it. The bar
/// is narrower than the screen, so the drag is scaled: one tab's width of
/// finger travel is one page, at any drag speed.
class _BarDrag extends StatefulWidget {
  const _BarDrag({required this.slot, required this.child});

  /// Width of one tab.
  final double slot;
  final Widget child;

  @override
  State<_BarDrag> createState() => _BarDragState();
}

class _BarDragState extends State<_BarDrag> {
  Drag? _drag;

  double get _scale {
    final c = homeTabController;
    if (c == null || !c.hasClients || widget.slot <= 0) return 1;
    // Negative: the capsule's chosen tab follows the finger (iOS), while a
    // page follows its own swipe the opposite way round.
    return -c.position.viewportDimension / widget.slot;
  }

  void _start(DragStartDetails d) {
    final c = homeTabController;
    if (c == null || !c.hasClients) return;
    _drag = c.position.drag(d, () => _drag = null);
  }

  void _update(DragUpdateDetails d) {
    final dx = (d.primaryDelta ?? d.delta.dx) * _scale;
    _drag?.update(
      DragUpdateDetails(
        globalPosition: d.globalPosition,
        delta: Offset(dx, 0),
        primaryDelta: dx,
      ),
    );
  }

  void _end(DragEndDetails d) {
    final v = d.velocity.pixelsPerSecond.dx * _scale;
    _drag?.end(
      DragEndDetails(
        velocity: Velocity(pixelsPerSecond: Offset(v, 0)),
        primaryVelocity: v,
      ),
    );
    _drag = null;
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onHorizontalDragStart: _start,
    onHorizontalDragUpdate: _update,
    onHorizontalDragEnd: _end,
    onHorizontalDragCancel: () {
      _drag?.cancel();
      _drag = null;
    },
    child: widget.child,
  );
}

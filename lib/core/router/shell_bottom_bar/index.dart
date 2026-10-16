import 'package:flutter/material.dart';

import 'nav_pill.dart';
import 'shell_pill_chrome.dart';
import 'shell_pill_metrics.dart';
import 'shell_quick_button.dart';
import 'shell_tabs.dart';

/// Floating capsule navigation.
class ShellBottomBar extends StatelessWidget {
  const ShellBottomBar({
    super.key,
    this.tabs = const [],
    this.selectedIndex = 0,
    this.onSelect,
    this.labelOf,
    this.unread = 0,
    this.onReorder,
    this.quickButton,
  });

  /// The destinations in the bar.
  final List<ShellTab> tabs;
  final int selectedIndex;
  final ValueChanged<int>? onSelect;

  /// Resolves a tab's translated label.
  final String Function(ShellTab tab)? labelOf;
  final int unread;
  final void Function(int from, int to)? onReorder;

  /// A separate round button on the right, outside the pill. Null = none.
  final ShellQuickButton? quickButton;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        // The pill and the quick button are one centred group, so the button
        // sits right beside the pill rather than out at the screen edge.
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(child: _fit(_pill())),
              if (quickButton != null) ...[
                const SizedBox(width: 10),
                quickButton!,
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _pill() => ShellPillChrome(
    child: SizedBox(
      height: ShellPillMetrics.height,
      child: NavPill(
        tabs: tabs,
        selectedIndex: selectedIndex,
        onSelect: onSelect ?? (_) {},
        labelOf: labelOf ?? (tab) => tab.labelKey,
        unread: unread,
        onReorder: onReorder,
      ),
    ),
  );

  /// As wide as its tabs ask for (never under [NavPill.minWidth]), so fewer
  /// tabs mean a narrower capsule. Never wider than the room the screen
  /// leaves it.
  Widget _fit(Widget child) {
    if (tabs.isEmpty) return child;
    return SizedBox(width: NavPill.widthFor(tabs.length), child: child);
  }
}

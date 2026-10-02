import 'package:flutter/material.dart';

import 'nav_pill.dart';
import 'shell_pill_chrome.dart';
import 'shell_pill_metrics.dart';
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
  });

  /// The destinations in the bar.
  final List<ShellTab> tabs;
  final int selectedIndex;
  final ValueChanged<int>? onSelect;

  /// Resolves a tab's translated label.
  final String Function(ShellTab tab)? labelOf;
  final int unread;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: _fit(
          ShellPillChrome(
            child: SizedBox(
              height: ShellPillMetrics.height,
              child: NavPill(
                tabs: tabs,
                selectedIndex: selectedIndex,
                onSelect: onSelect ?? (_) {},
                labelOf: labelOf ?? (tab) => tab.labelKey,
                unread: unread,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// As wide as its tabs ask for (never under [NavPill.minWidth]), centred,
  /// so fewer tabs mean a narrower capsule. Never wider than the room the
  /// screen leaves it.
  Widget _fit(Widget child) {
    if (tabs.isEmpty) return child;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: NavPill.widthFor(tabs.length)),
        child: child,
      ),
    );
  }
}

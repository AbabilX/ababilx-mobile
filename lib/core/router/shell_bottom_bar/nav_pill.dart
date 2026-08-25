import 'package:flutter/material.dart';

import 'nav_tab_item.dart';
import 'shell_pill_metrics.dart';
import 'shell_tabs.dart';

/// Capsule navigation destinations, rendered from whatever [tabs] the account
/// actually has — Messages alone, up to Messages | Wall | CRM | Board.
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

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Row(
        children: [
          for (var i = 0; i < tabs.length; i++)
            NavTabItem(
              icon: tabs[i].icon,
              selectedIcon: tabs[i].selectedIcon,
              label: labelOf(tabs[i]),
              selected: selectedIndex == i,
              badgeCount: tabs[i].showsUnread ? unread : 0,
              onTap: () => onSelect(i),
            ),
        ],
      ),
    );
  }
}

import 'package:hugeicons/hugeicons.dart';

/// One home-shell destination.
///
/// The bar is built from a list of these, so a tab's position is derived, never
/// hardcoded.
class ShellTab {
  const ShellTab({
    required this.route,
    required this.labelKey,
    required this.icon,
    required this.selectedIcon,
    this.showsUnread = false,
  });

  /// Route pushed on tap, and the prefix that marks this tab selected.
  final String route;

  /// [AppTranslations] key — resolved by the shell, which owns the context.
  final String labelKey;

  final List<List<dynamic>> icon;
  final List<List<dynamic>> selectedIcon;

  /// Whether the unread-message badge rides on this tab.
  final bool showsUnread;
}

const messagesShellTab = ShellTab(
  route: '/messages',
  labelKey: 'messages',
  icon: HugeIcons.strokeRoundedBubbleChat,
  selectedIcon: HugeIcons.strokeRoundedMessage01,
  showsUnread: true,
);

const callsShellTab = ShellTab(
  route: '/calls',
  labelKey: 'calls',
  icon: HugeIcons.strokeRoundedCall02,
  selectedIcon: HugeIcons.strokeRoundedCall,
);

/// Destinations in the home bottom bar: Messages and Calls, the two-tab
/// Signal shape. Workspace tabs (Wall, Board, CRM) were removed from mobile.
const List<ShellTab> homeShellTabs = [messagesShellTab, callsShellTab];

/// Index of the tab owning [location], or 0 when nothing matches.
int shellTabIndex(List<ShellTab> tabs, String location) {
  for (var i = 0; i < tabs.length; i++) {
    if (location.startsWith(tabs[i].route)) return i;
  }
  return 0;
}

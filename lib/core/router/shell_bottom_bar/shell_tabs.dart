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

const homeShellTab = ShellTab(
  route: '/home',
  labelKey: 'home',
  icon: HugeIcons.strokeRoundedHome01,
  selectedIcon: HugeIcons.strokeRoundedHome03,
);

const messagesShellTab = ShellTab(
  route: '/messages',
  labelKey: 'messages',
  icon: HugeIcons.strokeRoundedBubbleChat,
  selectedIcon: HugeIcons.strokeRoundedMessage01,
  showsUnread: true,
);

/// Discord-style communities (SPACES.md). Its own service; the tab still
/// works offline from the saved copy.
const spacesShellTab = ShellTab(
  route: '/spaces',
  labelKey: 'spaces',
  icon: HugeIcons.strokeRoundedUserGroup03,
  selectedIcon: HugeIcons.strokeRoundedUserGroup,
);

const callsShellTab = ShellTab(
  route: '/calls',
  labelKey: 'calls',
  icon: HugeIcons.strokeRoundedCall02,
  selectedIcon: HugeIcons.strokeRoundedCall,
);

/// Destinations in the home bottom bar: Home (Slack's quick views), Messages,
/// Spaces and Calls. Workspace tabs (Wall, Board, CRM) were removed from mobile.
const List<ShellTab> homeShellTabs = [
  homeShellTab,
  messagesShellTab,
  spacesShellTab,
  callsShellTab,
];

/// Index of the tab owning [location]. Nothing matching falls back to
/// Messages, not to whatever tab happens to sit first — Home is first, and
/// is not where a stray route goes.
int shellTabIndex(List<ShellTab> tabs, String location) {
  for (var i = 0; i < tabs.length; i++) {
    if (location.startsWith(tabs[i].route)) return i;
  }
  final messages = tabs.indexWhere((t) => t.route == messagesShellTab.route);
  return messages < 0 ? 0 : messages;
}

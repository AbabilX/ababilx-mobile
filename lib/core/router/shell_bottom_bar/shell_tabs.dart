import 'package:hugeicons/hugeicons.dart';

/// One home-shell destination.
///
/// The bar is built from a list of these, so a tab's position is derived, never
/// hardcoded — hiding Wall or Board cannot shift another tab's index out from
/// under it the way the old `showCrm ? 3 : 2` arithmetic could.
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

const wallShellTab = ShellTab(
  route: '/wall',
  labelKey: 'wall',
  icon: HugeIcons.strokeRoundedNews,
  selectedIcon: HugeIcons.strokeRoundedNews,
);

const crmShellTab = ShellTab(
  route: '/crm',
  labelKey: 'crm',
  icon: HugeIcons.strokeRoundedBriefcase01,
  selectedIcon: HugeIcons.strokeRoundedBriefcase02,
);

const boardShellTab = ShellTab(
  route: '/board',
  labelKey: 'board',
  icon: HugeIcons.strokeRoundedTask01,
  selectedIcon: HugeIcons.strokeRoundedTask02,
);

/// Destinations visible to this account in the home bottom bar.
///
/// Messages and Calls are the floor — they work with no workspace at all, so a
/// team-less account gets the two-tab Signal shape. Wall, Board and CRM are
/// workspace features: without a team they are permanently empty, so they stay
/// out of the bar entirely until the user joins one.
///
/// [showWallTab] / [showCrmTab] / [showBoardTab] are device-local prefs
/// (Settings → Navigation). They only filter the bar; deep links still open
/// those routes when the account has access.
List<ShellTab> visibleShellTabs({
  required bool hasTeam,
  required bool showCrm,
  bool showWallTab = true,
  bool showCrmTab = true,
  bool showBoardTab = true,
}) => [
  messagesShellTab,
  callsShellTab,
  if (hasTeam && showWallTab) wallShellTab,
  if (hasTeam && showCrm && showCrmTab) crmShellTab,
  if (hasTeam && showBoardTab) boardShellTab,
];

/// True when [location] needs workspace/CRM access the account no longer has.
///
/// Pref-hidden tabs do **not** count — the user asked only to drop the BNB
/// chrome, not to lock the route.
bool shellRouteAccessDenied(
  String location, {
  required bool hasTeam,
  required bool showCrm,
}) {
  if (location.startsWith('/wall') || location.startsWith('/board')) {
    return !hasTeam;
  }
  if (location.startsWith('/crm')) {
    return !hasTeam || !showCrm;
  }
  return false;
}

/// Index of the tab owning [location], or 0 when nothing matches — a route
/// whose tab is hidden (e.g. /crm after leaving a team) falls back to Messages.
int shellTabIndex(List<ShellTab> tabs, String location) {
  for (var i = 0; i < tabs.length; i++) {
    if (location.startsWith(tabs[i].route)) return i;
  }
  return 0;
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/crm/providers/crm_contacts_ui_provider.dart';
import '../../features/crm/providers/crm_followups_ui_provider.dart';
import '../../features/crm/providers/crm_leads_ui_provider.dart';
import '../../features/crm/providers/crm_organizations_ui_provider.dart';
import '../../features/messages/providers/chat_provider.dart';
import '../../features/messages/providers/team_gate_provider.dart';
import '../../features/notifications/widgets/battery_optimization_bootstrap.dart';
import '../../features/policy/widgets/policy_gate_overlay.dart';
import '../../features/wall/providers/wall_ui_provider.dart';
import '../../core/localization/app_translations.dart';
import 'shell_bottom_bar/crm_list_bar.dart';
import 'shell_bottom_bar/index.dart';
import 'shell_bottom_bar/shell_chrome_provider.dart';
import 'shell_bottom_bar/shell_tabs.dart';

/// Floating capsule nav, or CRM list [My|Add|All] + search action.
class HomeShell extends ConsumerWidget {
  const HomeShell({super.key, required this.child});
  final Widget child;

  bool _isCrmList(String location) =>
      location == '/crm/contacts' ||
      location == '/crm/leads' ||
      location == '/crm/followups' ||
      location == '/crm/organizations';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasTeam = ref.watch(hasTeamProvider);
    final showCrm = ref.watch(canViewCrmProvider);
    final tabs = visibleShellTabs(hasTeam: hasTeam, showCrm: showCrm);
    final location = GoRouterState.of(context).matchedLocation;
    final idx = shellTabIndex(tabs, location);
    final unread = ref.watch(totalUnreadProvider);

    final isContacts = location == '/crm/contacts';
    final isLeads = location == '/crm/leads';
    final isFollowups = location == '/crm/followups';
    final isOrganizations = location == '/crm/organizations';
    final shellBarHidden = ref.watch(shellBottomBarHiddenProvider);

    // A route whose tab is gone (left the team, lost CRM access) has no home
    // to go back to — bounce to Messages, the one tab every account has.
    // Only once the team is actually resolved: while it loads `hasTeam` is
    // false, and bouncing then would kick a deep link off /board or /wall.
    final teamResolved = ref.watch(teamGateProvider).hasValue;
    final onHiddenRoute =
        teamResolved &&
        !tabs.any((t) => location.startsWith(t.route)) &&
        location != '/profile';
    if (onHiddenRoute) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go('/messages');
      });
    }

    final hideBar =
        shellBarHidden ||
        (isContacts && ref.watch(crmContactsUiProvider).formSheetOpen) ||
        (isLeads && ref.watch(crmLeadsUiProvider).formSheetOpen) ||
        (isFollowups && ref.watch(crmFollowupsUiProvider).formSheetOpen) ||
        (isOrganizations &&
            ref.watch(crmOrganizationsUiProvider).formSheetOpen) ||
        ref.watch(wallUiProvider).hideBottomBar;

    final Widget? bar = hideBar
        ? null
        : _isCrmList(location)
        ? CrmListBottomBar(
            isLeads: isLeads,
            isFollowups: isFollowups,
            isOrganizations: isOrganizations,
          )
        : ShellBottomBar(
            mode: ShellBottomBarMode.home,
            tabs: tabs,
            selectedIndex: idx,
            unread: unread,
            labelOf: (tab) =>
                AppTranslations.translate(context, ref, tab.labelKey),
            onSelect: (i) => context.go(tabs[i].route),
          );

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(child: child),
          const BatteryOptimizationBootstrap(),
          const PolicyGateOverlay(),
          if (bar != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Material(type: MaterialType.transparency, child: bar),
            ),
        ],
      ),
    );
  }
}

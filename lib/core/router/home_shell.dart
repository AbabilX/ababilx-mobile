import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/crm/crm-contacts/contact_search.dart';
import '../../features/crm/crm-followups/followup_search.dart';
import '../../features/crm/crm-leads/lead_search.dart';
import '../../features/crm/providers/crm_contacts_ui_provider.dart';
import '../../features/crm/providers/crm_followups_ui_provider.dart';
import '../../features/crm/providers/crm_leads_ui_provider.dart';
import '../../features/messages/chat-list/chat_search.dart';
import '../../features/messages/providers/chat_provider.dart';
import '../../features/messages/providers/team_gate_provider.dart';
import '../../features/wall/providers/wall_ui_provider.dart';
import '../../features/wall/wall-search/wall_search.dart';
import '../../core/localization/app_translations.dart';
import 'shell_bottom_bar/index.dart';

/// Bottom nav: home pills, or CRM list [My|Add|All] + search.
class HomeShell extends ConsumerWidget {
  const HomeShell({super.key, required this.child});
  final Widget child;

  static const _tabsWithCrm = ['/messages', '/wall', '/crm', '/profile'];
  static const _tabsNoCrm = ['/messages', '/wall', '/profile'];

  int _currentIndex(BuildContext context, {required bool showCrm}) {
    final location = GoRouterState.of(context).matchedLocation;
    if (location.startsWith('/profile')) return showCrm ? 3 : 2;
    if (location.startsWith('/crm')) return showCrm ? 2 : 0;
    if (location.startsWith('/wall')) return 1;
    return 0;
  }

  bool _isContacts(String location) =>
      location == '/crm/contacts' || location.startsWith('/crm/contacts/');

  bool _isLeads(String location) => location == '/crm/leads';

  bool _isFollowups(String location) =>
      location == '/crm/followups' || location.startsWith('/crm/followups/');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showCrm = ref.watch(canViewCrmProvider);
    final tabs = showCrm ? _tabsWithCrm : _tabsNoCrm;
    final idx = _currentIndex(context, showCrm: showCrm);
    final unread = ref.watch(totalUnreadProvider);
    final location = GoRouterState.of(context).matchedLocation;
    final isContacts = _isContacts(location);
    final isLeads = _isLeads(location);
    final isFollowups = _isFollowups(location);
    final isCrmList = isContacts || isLeads || isFollowups;
    final contactsUi = ref.watch(crmContactsUiProvider);
    final leadsUi = ref.watch(crmLeadsUiProvider);
    final followupsUi = ref.watch(crmFollowupsUiProvider);
    final wallUi = ref.watch(wallUiProvider);

    if (!showCrm && location.startsWith('/crm')) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go('/messages');
      });
    }

    final hideBar = (isContacts && contactsUi.formSheetOpen) ||
        (isLeads && leadsUi.formSheetOpen) ||
        (isFollowups && followupsUi.formSheetOpen) ||
        wallUi.hideBottomBar;

    final mineSelected = isFollowups
        ? followupsUi.scope == FollowupScope.mine
        : isLeads
            ? leadsUi.scope == LeadScope.mine
            : contactsUi.scope == ContactScope.mine;
    final canAdd = isFollowups
        ? followupsUi.canCreate
        : isLeads
            ? leadsUi.canCreate
            : contactsUi.canCreate;

    final Widget? bar = hideBar
        ? null
        : isCrmList
            ? ShellBottomBar(
                mode: ShellBottomBarMode.contacts,
                contactsMineSelected: mineSelected,
                addLabel: AppTranslations.translate(
                  context,
                  ref,
                  'crm_add_short',
                ),
                mineLabel: AppTranslations.translate(
                  context,
                  ref,
                  'crm_my_short',
                ),
                allLabel: AppTranslations.translate(
                  context,
                  ref,
                  'crm_all_short',
                ),
                canAdd: canAdd,
                onAdd: () {
                  if (isFollowups) {
                    ref
                        .read(crmFollowupsUiProvider.notifier)
                        .setFormSheetOpen(true);
                    ref.read(crmFollowupsUiProvider.notifier).requestAdd();
                  } else if (isLeads) {
                    ref.read(crmLeadsUiProvider.notifier).setFormSheetOpen(true);
                    ref.read(crmLeadsUiProvider.notifier).requestAdd();
                  } else {
                    ref
                        .read(crmContactsUiProvider.notifier)
                        .setFormSheetOpen(true);
                    ref.read(crmContactsUiProvider.notifier).requestAdd();
                  }
                },
                onSelectMine: () {
                  if (isFollowups) {
                    ref
                        .read(crmFollowupsUiProvider.notifier)
                        .setScope(FollowupScope.mine);
                  } else if (isLeads) {
                    ref
                        .read(crmLeadsUiProvider.notifier)
                        .setScope(LeadScope.mine);
                  } else {
                    ref
                        .read(crmContactsUiProvider.notifier)
                        .setScope(ContactScope.mine);
                  }
                },
                onSelectAll: () {
                  if (isFollowups) {
                    ref
                        .read(crmFollowupsUiProvider.notifier)
                        .setScope(FollowupScope.all);
                  } else if (isLeads) {
                    ref
                        .read(crmLeadsUiProvider.notifier)
                        .setScope(LeadScope.all);
                  } else {
                    ref
                        .read(crmContactsUiProvider.notifier)
                        .setScope(ContactScope.all);
                  }
                },
                onContactsSearch: () {
                  if (isFollowups) {
                    openFollowupSearch(context, ref);
                  } else if (isLeads) {
                    openLeadSearch(context, ref);
                  } else {
                    openContactSearch(context, ref);
                  }
                },
              )
            : ShellBottomBar(
                mode: ShellBottomBarMode.home,
                selectedIndex: idx,
                unread: unread,
                showCrm: showCrm,
                messagesLabel:
                    AppTranslations.translate(context, ref, 'messages'),
                wallLabel: AppTranslations.translate(context, ref, 'wall'),
                crmLabel: AppTranslations.translate(context, ref, 'crm'),
                profileLabel:
                    AppTranslations.translate(context, ref, 'profile'),
                onSelect: (i) => context.go(tabs[i]),
                onSearch: () {
                  if (idx == 1) {
                    openWallSearch(context, ref);
                  } else if (idx == 0) {
                    openChatSearch(context, ref);
                  }
                },
              );

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(child: child),
          if (bar != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Material(
                type: MaterialType.transparency,
                child: bar,
              ),
            ),
        ],
      ),
    );
  }
}

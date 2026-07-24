import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/crm/crm-contacts/contact_search.dart';
import '../../features/crm/providers/crm_contacts_ui_provider.dart';
import '../../features/messages/chat-list/chat_search.dart';
import '../../features/messages/providers/chat_provider.dart';
import '../../features/messages/providers/team_gate_provider.dart';
import '../../features/wall/wall-search/wall_search.dart';
import '../../core/localization/app_translations.dart';
import 'shell_bottom_bar/index.dart';

/// Bottom nav: home pills, or contacts [My|Add|All] + search.
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
      location == '/crm/contacts' || location.startsWith('/crm/contacts');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showCrm = ref.watch(canViewCrmProvider);
    final tabs = showCrm ? _tabsWithCrm : _tabsNoCrm;
    final idx = _currentIndex(context, showCrm: showCrm);
    final unread = ref.watch(totalUnreadProvider);
    final location = GoRouterState.of(context).matchedLocation;
    final isContacts = _isContacts(location);
    final contactsUi = ref.watch(crmContactsUiProvider);

    if (!showCrm && location.startsWith('/crm')) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go('/messages');
      });
    }

    return Scaffold(
      body: child,
      bottomNavigationBar: (isContacts && contactsUi.formSheetOpen)
          ? null
          : isContacts
              ? ShellBottomBar(
                  mode: ShellBottomBarMode.contacts,
                  contactsMineSelected:
                      contactsUi.scope == ContactScope.mine,
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
                  canAdd: contactsUi.canCreate,
                  onAdd: () {
                    // Hide bar immediately, then open sheet.
                    ref
                        .read(crmContactsUiProvider.notifier)
                        .setFormSheetOpen(true);
                    ref.read(crmContactsUiProvider.notifier).requestAdd();
                  },
                  onSelectMine: () => ref
                      .read(crmContactsUiProvider.notifier)
                      .setScope(ContactScope.mine),
                  onSelectAll: () => ref
                      .read(crmContactsUiProvider.notifier)
                      .setScope(ContactScope.all),
                  onContactsSearch: () {
                    openContactSearch(context, ref);
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
                ),
    );
  }
}

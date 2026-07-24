import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/messages/chat-list/chat_search.dart';
import '../../features/messages/providers/chat_provider.dart';
import '../../features/messages/providers/team_gate_provider.dart';
import '../../features/wall/wall-search/wall_search.dart';
import '../../core/localization/app_translations.dart';
import 'shell_bottom_bar/index.dart';

/// Bottom nav: Messages + Wall + CRM (permission-gated) + Profile.
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showCrm = ref.watch(canViewCrmProvider);
    final tabs = showCrm ? _tabsWithCrm : _tabsNoCrm;
    final idx = _currentIndex(context, showCrm: showCrm);
    final unread = ref.watch(totalUnreadProvider);

    // Deep-link / stale route: no CRM access while on /crm → bounce home.
    final location = GoRouterState.of(context).matchedLocation;
    if (!showCrm && location.startsWith('/crm')) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go('/messages');
      });
    }

    return Scaffold(
      body: child,
      bottomNavigationBar: ShellBottomBar(
        selectedIndex: idx,
        unread: unread,
        showCrm: showCrm,
        messagesLabel: AppTranslations.translate(context, ref, 'messages'),
        wallLabel: AppTranslations.translate(context, ref, 'wall'),
        crmLabel: AppTranslations.translate(context, ref, 'crm'),
        profileLabel: AppTranslations.translate(context, ref, 'profile'),
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

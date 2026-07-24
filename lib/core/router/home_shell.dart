import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/messages/chat-list/chat_search.dart';
import '../../features/messages/providers/chat_provider.dart';
import '../../core/localization/app_translations.dart';
import 'shell_bottom_bar/index.dart';

/// Bottom nav: Messages + Profile (floating pills) + search.
class HomeShell extends ConsumerWidget {
  const HomeShell({super.key, required this.child});
  final Widget child;

  static const _tabs = ['/messages', '/profile'];

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    if (location.startsWith('/profile')) return 1;
    return 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final idx = _currentIndex(context);
    final unread = ref.watch(totalUnreadProvider);

    return Scaffold(
      body: child,
      bottomNavigationBar: ShellBottomBar(
        selectedIndex: idx,
        unread: unread,
        messagesLabel: AppTranslations.translate(context, ref, 'messages'),
        profileLabel: AppTranslations.translate(context, ref, 'profile'),
        onSelect: (i) => context.go(_tabs[i]),
        onSearch: () => openChatSearch(context, ref),
      ),
    );
  }
}

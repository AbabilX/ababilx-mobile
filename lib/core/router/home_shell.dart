import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../features/messages/chat_icon.dart';
import '../../features/messages/providers/chat_provider.dart';
import '../../core/localization/app_translations.dart';

/// Bottom nav: Messages + Profile.
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
      bottomNavigationBar: NavigationBar(
        selectedIndex: idx,
        onDestinationSelected: (i) => context.go(_tabs[i]),
        destinations: [
          NavigationDestination(
            icon: Badge(
              isLabelVisible: unread > 0,
              label: Text(unread > 99 ? '99+' : '$unread'),
              child: const ChatIcon(HugeIcons.strokeRoundedBubbleChat),
            ),
            selectedIcon: const ChatIcon(HugeIcons.strokeRoundedMessage01),
            label: AppTranslations.translate(context, ref, 'messages'),
          ),
          NavigationDestination(
            icon: const ChatIcon(HugeIcons.strokeRoundedUser02),
            selectedIcon: const ChatIcon(HugeIcons.strokeRoundedUser03),
            label: AppTranslations.translate(context, ref, 'profile'),
          ),
        ],
      ),
    );
  }
}

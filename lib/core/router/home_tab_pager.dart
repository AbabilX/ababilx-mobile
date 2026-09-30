import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/calls/screens/calls_screen.dart';
import '../../features/messages/screens/messages_screen.dart';
import 'swipe_tab_pager.dart';

/// Chats and Talks, the two tabs every account has, in bar order: swipe left
/// on Chats for Talks, right on Talks for Chats. Wall, CRM and Board stay
/// tap-only.
const homePagerRoutes = ['/messages', '/calls'];

/// The page both routes build. The key is what makes it one page: the
/// navigator updates a page whose key it already holds rather than replacing
/// it, so switching tabs moves the pager instead of rebuilding it.
Page<void> homeTabPage(GoRouterState state, int index) => MaterialPage<void>(
  key: const ValueKey('home-tab-pager'),
  name: state.path,
  child: SwipeTabPager(
    index: index,
    routes: homePagerRoutes,
    pages: const [MessagesScreen(), CallsScreen()],
  ),
);

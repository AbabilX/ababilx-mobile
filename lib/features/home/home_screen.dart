import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/router/shell_bottom_bar/shell_pill_metrics.dart';
import '../../core/router/swipe_tab_active.dart';
import '../../shared/widgets/portrait_lock_scope.dart';
import '../messages/providers/chat_provider.dart';
import 'data/home_drafts.dart';
import 'header/home_focus_card.dart';
import 'header/home_header.dart';
import 'sections/home_callers_section.dart';
import 'sections/home_chat_sections.dart';
import 'sections/home_nearby_section.dart';

/// The Home tab. Top to bottom, from "what needs me" to "where was I":
///
/// greeting (fixed, never scrolls away) · focus card (unread, or all caught up) ·
/// pinned faces · nearby devices (only while one is here) · people to talk to
/// again · recent chats.
///
/// Drafts / Locked shortcuts live on the Messages filter row now. Everything
/// else is read from what Messages, Talks and Local Share already hold; Home
/// asks the server only for scheduled messages.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with SwipeTabVisits {
  /// Drafts are written while Home is hidden; read them again on the way back.
  @override
  void onTabShown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.invalidate(homeDraftsProvider);
      ref.invalidate(homeScheduledProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    return PortraitLockScope(
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          // The header stays put; only what is under it scrolls.
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const HomeHeader(),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(homeScheduledProvider);
                    ref.invalidate(homeDraftsProvider);
                    await ref.read(chatProvider.notifier).fetchSidebar();
                  },
                  child: ListView(
                    padding: EdgeInsets.only(
                      bottom: ShellPillMetrics.contentBottom(context) + 8,
                    ),
                    children: const [
                      HomeFocusCard(),
                      HomePinnedSection(),
                      HomeNearbySection(),
                      HomeCallersSection(),
                      HomeRecentChatsSection(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

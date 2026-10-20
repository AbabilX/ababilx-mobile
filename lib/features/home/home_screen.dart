import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/router/shell_bottom_bar/shell_pill_metrics.dart';
import '../../core/router/swipe_tab_active.dart';
import '../../shared/widgets/portrait_lock_scope.dart';
import '../messages/chat-list/filter_reorder_blur.dart';
import '../messages/providers/chat_provider.dart';
import 'data/home_drafts.dart';
import 'header/home_focus_card.dart';
import 'header/home_header.dart';
import 'quick-views/quick_views_row.dart';
import 'sections/home_callers_section.dart';
import 'sections/home_chat_sections.dart';
import 'sections/home_nearby_section.dart';

/// The Home tab. Top to bottom, from "what needs me" to "where was I":
///
/// greeting (fixed, never scrolls away) · focus card (unread, or all caught up) · shortcuts (hold and
/// drag to arrange) · pinned faces · nearby devices (only while one is
/// here) · people to talk to again · recent chats.
///
/// Everything is read from what Messages, Talks and Local Share already
/// hold; Home asks the server only for scheduled messages.
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
    // While a shortcut is held, everything but the shortcuts blurs.
    Widget blur(Widget child) =>
        FilterReorderBlur(on: quickViewReordering, child: child);
    return PortraitLockScope(
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          // The header stays put; only what is under it scrolls.
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              blur(const HomeHeader()),
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
                    children: [
                      blur(const HomeFocusCard()),
                      const QuickViewsRow(),
                      blur(
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            HomePinnedSection(),
                            HomeNearbySection(),
                            HomeCallersSection(),
                            HomeRecentChatsSection(),
                          ],
                        ),
                      ),
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

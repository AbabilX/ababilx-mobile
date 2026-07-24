import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/wall_provider.dart';
import '../wall-composer/composer_sheet.dart';
import 'feed_filters.dart';
import 'feed_sliver_body.dart';
import 'wall_create_post_button.dart';

class WallFeed extends ConsumerWidget {
  const WallFeed({super.key, required this.isPremium});

  final bool isPremium;

  bool _onScroll(ScrollNotification n, WidgetRef ref) {
    if (n.metrics.axis != Axis.vertical) return false;
    // Trigger ~320px before the end so the next page feels continuous.
    final remaining = n.metrics.maxScrollExtent - n.metrics.pixels;
    if (remaining < 320) {
      ref.read(wallProvider.notifier).loadMore();
    }
    return false;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(wallProvider);

    return Scaffold(
      extendBody: true,
      body: RefreshIndicator(
        onRefresh: () => ref.read(wallProvider.notifier).loadInitial(),
        // Edge offset so pull-to-refresh clears the floating app bar area.
        edgeOffset: MediaQuery.paddingOf(context).top + kToolbarHeight + 48,
        child: NotificationListener<ScrollNotification>(
          onNotification: (n) => _onScroll(n, ref),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverAppBar(
                floating: true,
                snap: true,
                pinned: false,
                title: const Text(
                  'Wall',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                actions: [
                  WallCreatePostButton(
                    onPressed: () => showWallComposerSheet(
                      context,
                      ref,
                      isPremium: isPremium,
                    ),
                  ),
                ],
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(48),
                  child: WallFeedFilters(
                    filter: state.filter,
                    categories: state.categories,
                    onSelect: (f) =>
                        ref.read(wallProvider.notifier).setFilter(f),
                  ),
                ),
              ),
              ...wallFeedSlivers(context, ref, state),
            ],
          ),
        ),
      ),
    );
  }
}

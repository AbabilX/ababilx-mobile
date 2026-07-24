import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/wall_provider.dart';
import '../wall-composer/composer_sheet.dart';
import 'feed_filters.dart';
import 'feed_sliver_body.dart';
import 'wall_fab.dart';

class WallFeed extends ConsumerWidget {
  const WallFeed({super.key, required this.isPremium});

  final bool isPremium;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(wallProvider);

    return Scaffold(
      floatingActionButton: WallFab(
        onPressed: () => showWallComposerSheet(
          context,
          ref,
          isPremium: isPremium,
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: RefreshIndicator(
        onRefresh: () => ref.read(wallProvider.notifier).loadInitial(),
        // Edge offset so pull-to-refresh clears the floating app bar area.
        edgeOffset: MediaQuery.paddingOf(context).top + kToolbarHeight + 48,
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
    );
  }
}

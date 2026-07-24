import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../messages/chat-empty-state/index.dart';
import '../providers/wall_provider.dart';
import '../providers/wall_state.dart';
import '../wall-composer/composer_sheet.dart';
import '../wall-post/post_card.dart';
import 'feed_filters.dart';
import 'wall_fab.dart';

class WallFeed extends ConsumerWidget {
  const WallFeed({super.key, required this.isPremium});

  final bool isPremium;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(wallProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Wall',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: WallFeedFilters(
            filter: state.filter,
            categories: state.categories,
            onSelect: (f) => ref.read(wallProvider.notifier).setFilter(f),
          ),
        ),
      ),
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
        child: _body(context, ref, state),
      ),
    );
  }

  Widget _body(
    BuildContext context,
    WidgetRef ref,
    WallState state,
  ) {
    if (state.loading && state.posts.isEmpty) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2.5));
    }
    if (state.error != null && state.posts.isEmpty) {
      return ListView(
        children: [
          SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.5,
            child: ChatEmptyState(
              title: 'Could not load wall',
              subtitle: state.error,
              icon: Icons.error_outline,
            ),
          ),
        ],
      );
    }
    if (state.posts.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 120),
          ChatEmptyState(
            title: 'No posts yet',
            subtitle: 'Be the first to share an update with your team.',
            icon: Icons.newspaper_outlined,
          ),
        ],
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
      itemCount: state.posts.length + (state.hasMore ? 1 : 0),
      itemBuilder: (context, i) {
        if (i >= state.posts.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: state.loadingMore
                  ? const CircularProgressIndicator(strokeWidth: 2.5)
                  : TextButton(
                      onPressed: () =>
                          ref.read(wallProvider.notifier).loadMore(),
                      child: const Text('Load more'),
                    ),
            ),
          );
        }
        final post = state.posts[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: WallPostCard(
            post: post,
            onOpen: () => context.push('/wall/post/${post.id}'),
          ),
        );
      },
    );
  }
}

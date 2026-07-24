import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/shell_bottom_bar/shell_pill_metrics.dart';
import '../../messages/chat-empty-state/index.dart';
import '../providers/wall_state.dart';
import '../wall-post/post_card.dart';

/// Feed posts / empty / error as slivers (pairs with floating Wall app bar).
List<Widget> wallFeedSlivers(
  BuildContext context,
  WidgetRef ref,
  WallState state,
) {
  if (state.loading && state.posts.isEmpty) {
    return [
      const SliverFillRemaining(
        hasScrollBody: false,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
      ),
    ];
  }

  if (state.error != null && state.posts.isEmpty) {
    return [
      SliverFillRemaining(
        hasScrollBody: false,
        child: ChatEmptyState(
          title: 'Could not load wall',
          subtitle: state.error,
          icon: Icons.error_outline,
        ),
      ),
    ];
  }

  if (state.posts.isEmpty) {
    return [
      const SliverFillRemaining(
        hasScrollBody: false,
        child: ChatEmptyState(
          title: 'No posts yet',
          subtitle: 'Be the first to share an update with your team.',
          icon: Icons.newspaper_outlined,
        ),
      ),
    ];
  }

  final count = state.posts.length + (state.hasMore ? 1 : 0);
  return [
    SliverPadding(
      padding: const EdgeInsets.fromLTRB(
        16,
        8,
        16,
        ShellPillMetrics.contentBottomInset,
      ),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, i) {
            if (i >= state.posts.length) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
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
          childCount: count,
        ),
      ),
    ),
  ];
}

import 'package:flutter/material.dart';
import 'package:ababilx/shared/widgets/app_bar_back_button.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/root_back.dart';
import '../data/models/wall_models.dart';
import '../providers/wall_provider.dart';
import '../wall-comments/comment_composer.dart';
import '../wall-comments/comment_thread.dart';
import '../wall-post/post_card.dart';

class WallPostScreen extends ConsumerStatefulWidget {
  const WallPostScreen({super.key, required this.postId});

  final String postId;

  @override
  ConsumerState<WallPostScreen> createState() => _WallPostScreenState();
}

class _WallPostScreenState extends ConsumerState<WallPostScreen> {
  WallComment? _replyTo;

  WallPost _resolve(WallPost fetched, List<WallPost> feed) {
    for (final p in feed) {
      if (p.id == fetched.id) return p;
    }
    return fetched;
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(wallPostProvider(widget.postId));
    final feed = ref.watch(wallProvider).posts;
    final scheme = Theme.of(context).colorScheme;
    final parentId = _replyTo == null
        ? null
        : (_replyTo!.parentId ?? _replyTo!.id);

    return PopScope(
      canPop:
          GoRouter.maybeOf(context)?.canPop() ?? Navigator.of(context).canPop(),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) popOrGoHome(context);
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            onPressed: () => popOrGoHome(context),
            icon: const AppBarBackIcon(),
          ),
          title: const Text('Post'),
        ),
        body: async.when(
          loading: () =>
              const Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
          error: (e, _) => Center(child: Text('Failed to load\n$e')),
          data: (post) {
            final shown = _resolve(post, feed);
            return Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    children: [
                      WallPostCard(post: shown, expanded: true),
                      const SizedBox(height: 16),
                      Text(
                        'Comments',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: scheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 8),
                      WallCommentThread(
                        post: shown,
                        onReply: (c) => setState(() => _replyTo = c),
                      ),
                    ],
                  ),
                ),
                WallCommentComposer(
                  postId: shown.id,
                  parentId: parentId,
                  replyLabel: _replyTo?.userName,
                  onClearReply: () => setState(() => _replyTo = null),
                  onSent: () => setState(() => _replyTo = null),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

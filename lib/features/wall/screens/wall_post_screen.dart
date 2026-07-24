import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../messages/chat_icon.dart';
import '../data/models/wall_models.dart';
import '../providers/wall_provider.dart';
import '../wall-comments/comment_thread.dart';
import '../wall-post/post_card.dart';

class WallPostScreen extends ConsumerWidget {
  const WallPostScreen({super.key, required this.postId});

  final String postId;

  WallPost _resolve(WallPost fetched, List<WallPost> feed) {
    for (final p in feed) {
      if (p.id == fetched.id) return p;
    }
    return fetched;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(wallPostProvider(postId));
    final feed = ref.watch(wallProvider).posts;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const ChatIcon(HugeIcons.strokeRoundedArrowLeft01),
        ),
        title: const Text('Post'),
      ),
      body: async.when(
        loading: () => const Center(
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
        error: (e, _) => Center(child: Text('Failed to load\n$e')),
        data: (post) {
          final shown = _resolve(post, feed);
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
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
              WallCommentThread(post: shown),
            ],
          );
        },
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:ababilx/shared/widgets/app_bar_back_button.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/models/wall_models.dart';
import '../data/wall_repository.dart';
import '../wall_utils.dart';

Future<void> openWallSearch(BuildContext context, WidgetRef ref) async {
  await showSearch<void>(context: context, delegate: WallSearchDelegate(ref));
}

class WallSearchDelegate extends SearchDelegate<void> {
  WallSearchDelegate(this.ref);
  final WidgetRef ref;

  @override
  List<Widget>? buildActions(BuildContext context) => [
    if (query.isNotEmpty)
      IconButton(onPressed: () => query = '', icon: const Icon(Icons.clear)),
  ];

  @override
  Widget? buildLeading(BuildContext context) => IconButton(
    onPressed: () => close(context, null),
    icon: const AppBarBackIcon(),
  );

  @override
  Widget buildResults(BuildContext context) => _build(context);

  @override
  Widget buildSuggestions(BuildContext context) {
    if (query.trim().length < 2) {
      return const Center(child: Text('Type at least 2 characters'));
    }
    return _build(context);
  }

  Widget _build(BuildContext context) {
    return FutureBuilder<WallSearchResponse>(
      future: ref.read(wallRepositoryProvider).search(query.trim()),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(
            child: CircularProgressIndicator(strokeWidth: 2.5),
          );
        }
        if (snap.hasError) {
          return Center(child: Text('Search failed: ${snap.error}'));
        }
        final data = snap.data!;
        if (data.posts.isEmpty && data.comments.isEmpty) {
          return const Center(child: Text('No results'));
        }
        return ListView(
          children: [
            for (final hit in data.posts)
              ListTile(
                title: Text(
                  wallBodyPreview(hit.post.body),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(hit.excerpt),
                onTap: () {
                  close(context, null);
                  context.push('/wall/post/${hit.post.id}');
                },
              ),
            for (final hit in data.comments)
              ListTile(
                leading: const Icon(Icons.comment_outlined),
                title: Text(
                  wallBodyPreview(hit.comment.body),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(hit.excerpt),
                onTap: () {
                  close(context, null);
                  context.push('/wall/post/${hit.postId}');
                },
              ),
          ],
        );
      },
    );
  }
}

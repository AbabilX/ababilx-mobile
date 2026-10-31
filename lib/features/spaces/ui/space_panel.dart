import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/router/shell_bottom_bar/shell_pill_metrics.dart';
import '../data/space_models.dart';
import '../providers/spaces_providers.dart';
import 'channel_row.dart';
import 'spaces_states.dart';

/// One Space's sidebar: its name, then loose channels, then categories.
/// Works from the saved copy when the service or network is down.
class SpacePanel extends ConsumerWidget {
  const SpacePanel({
    super.key,
    required this.space,
    required this.onOpenChannel,
  });

  final SpaceSummary space;
  final void Function(String spaceId, String channelId) onOpenChannel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final load = ref.watch(spaceTreeProvider(space.id));
    final notifier = ref.read(spaceTreeProvider(space.id).notifier);
    final tree = load.data;
    final name = (tree?.name.isNotEmpty ?? false) ? tree!.name : space.name;

    final Widget body;
    if (tree == null && load.failure != null) {
      body = KeyedSubtree(
        key: const Key('channels-error'),
        child: SpacesErrorView(
          failure: load.failure!,
          onRetry: notifier.refresh,
          busy: load.loading,
        ),
      );
    } else if (tree == null) {
      body = const SpacesSkeleton(railOnly: true);
    } else {
      body = RefreshIndicator(
        onRefresh: notifier.refresh,
        child: _ChannelList(
          tree: tree,
          onOpen: (id) => onOpenChannel(space.id, id),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Divider(height: 1, color: theme.colorScheme.outlineVariant),
        if (tree != null && load.failure != null)
          SpacesBanner(
            failure: load.failure!,
            onRetry: notifier.refresh,
            busy: load.loading,
          ),
        Expanded(child: body),
      ],
    );
  }
}

class _ChannelList extends ConsumerWidget {
  const _ChannelList({required this.tree, required this.onOpen});

  final SpaceTree tree;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final collapsed = ref.watch(collapsedCategoriesProvider);
    final toggle = ref.read(collapsedCategoriesProvider.notifier).toggle;
    Widget row(SpaceChannel ch) => ChannelRow(
      key: Key('channel-${ch.id}'),
      channel: ch,
      onTap: () => onOpen(ch.id),
    );

    final empty =
        tree.channels.isEmpty &&
        tree.categories.every((k) => k.channels.isEmpty);
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.only(
        top: 6,
        bottom: ShellPillMetrics.contentBottom(context),
      ),
      children: [
        if (empty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'No channels you can see yet.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        for (final ch in tree.channels) row(ch),
        for (final cat in tree.categories) ...[
          CategoryHeader(
            category: cat,
            collapsed: collapsed.contains(cat.id),
            onTap: () => toggle(cat.id),
          ),
          for (final ch in cat.channels)
            // A folded category still shows what needs reading.
            if (!collapsed.contains(cat.id) || ch.unread || ch.mentions > 0)
              row(ch),
        ],
      ],
    );
  }
}

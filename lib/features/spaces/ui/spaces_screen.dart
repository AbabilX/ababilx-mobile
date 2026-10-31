import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/portrait_lock_scope.dart';
import '../providers/spaces_providers.dart';
import 'space_add_sheet.dart';
import 'space_panel.dart';
import 'space_rail.dart';
import 'spaces_empty.dart';
import 'spaces_states.dart';

/// The Spaces tab: rail of Spaces on the left, the chosen Space's channels
/// on the right (Discord's layout, the app's own theme). Every state has a
/// way forward: skeleton while loading, saved copy + banner when offline,
/// an error with Retry when nothing is saved, create/join when empty.
class SpacesScreen extends ConsumerWidget {
  const SpacesScreen({super.key, this.onOpenChannel});

  /// Defaults to pushing the channel route; tests pass their own.
  final void Function(String spaceId, String channelId)? onOpenChannel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final load = ref.watch(spacesListProvider);
    final list = ref.read(spacesListProvider.notifier);
    final selectedId = ref.watch(selectedSpaceIdProvider);
    final spaces = load.data;
    final open = onOpenChannel ?? (s, c) => context.push('/spaces/$s/c/$c');

    final Widget body;
    if (spaces == null && load.failure != null) {
      body = KeyedSubtree(
        key: const Key('spaces-error'),
        child: SpacesErrorView(
          failure: load.failure!,
          onRetry: list.refresh,
          busy: load.loading,
        ),
      );
    } else if (spaces == null) {
      body = const SpacesSkeleton();
    } else if (spaces.isEmpty) {
      body = Column(
        children: [
          if (load.failure != null)
            SpacesBanner(
              failure: load.failure!,
              onRetry: list.refresh,
              busy: load.loading,
            ),
          Expanded(
            child: SpacesEmptyView(
              onCreate: () => showCreateSpaceSheet(context, ref),
              onJoin: () => showJoinSpaceSheet(context, ref),
            ),
          ),
        ],
      );
    } else {
      final space = spaces.firstWhere(
        (s) => s.id == selectedId,
        orElse: () => spaces.first,
      );
      body = Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SpaceRail(
            spaces: spaces,
            selectedId: space.id,
            onSelect: ref.read(selectedSpaceNotifierProvider.notifier).select,
            onAdd: () => showAddSpaceSheet(context, ref),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (load.failure != null)
                  SpacesBanner(
                    failure: load.failure!,
                    onRetry: list.refresh,
                    busy: load.loading,
                  ),
                Expanded(
                  child: SpacePanel(
                    key: ValueKey(space.id),
                    space: space,
                    onOpenChannel: open,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return PortraitLockScope(
      child: Scaffold(body: SafeArea(bottom: false, child: body)),
    );
  }
}

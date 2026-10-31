import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'spaces_providers.dart';

/// The Space the user last picked (device-local, per account). The id may
/// name a Space they have since left; [selectedSpaceIdProvider] resolves it.
class SelectedSpaceNotifier extends Notifier<String?> {
  @override
  String? build() {
    ref.watch(spaceSessionProvider);
    Future.microtask(() async {
      try {
        final saved = await (await spaceCacheOf(ref)).readSelected();
        if (saved != null && state == null) state = saved;
      } catch (_) {}
    });
    return null;
  }

  Future<void> select(String id) async {
    state = id;
    try {
      await (await spaceCacheOf(ref)).writeSelected(id);
    } catch (_) {}
  }
}

final selectedSpaceNotifierProvider =
    NotifierProvider<SelectedSpaceNotifier, String?>(SelectedSpaceNotifier.new);

/// The Space to draw: the saved pick if it is still in the rail, else the
/// first one, else none.
final selectedSpaceIdProvider = Provider<String?>((ref) {
  final spaces = ref.watch(spacesListProvider).data ?? const [];
  final picked = ref.watch(selectedSpaceNotifierProvider);
  if (spaces.isEmpty) return null;
  for (final s in spaces) {
    if (s.id == picked) return picked;
  }
  return spaces.first.id;
});

/// Category ids the user folded (device-local, per account).
class CollapsedCategoriesNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() {
    ref.watch(spaceSessionProvider);
    Future.microtask(() async {
      try {
        final saved = await (await spaceCacheOf(ref)).readCollapsed();
        if (saved.isNotEmpty) state = saved;
      } catch (_) {}
    });
    return const {};
  }

  Future<void> toggle(String categoryId) async {
    final next = {...state};
    if (!next.remove(categoryId)) next.add(categoryId);
    state = next;
    try {
      await (await spaceCacheOf(ref)).writeCollapsed(next);
    } catch (_) {}
  }
}

final collapsedCategoriesProvider =
    NotifierProvider<CollapsedCategoriesNotifier, Set<String>>(
      CollapsedCategoriesNotifier.new,
    );

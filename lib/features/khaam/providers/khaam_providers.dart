import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/khaam_opened_store.dart';

final khaamOpenedStoreProvider = Provider<KhaamOpenedStore>(
  (ref) => const KhaamOpenedStore(),
);

/// Every Khaam opened on this phone, read once and kept in memory. The bubble
/// and the chat-list preview both watch it, so scratching a card open shows
/// its message in the list the moment the open screen closes.
///
/// While it loads, nothing counts as opened: a message hidden a beat too long
/// costs nothing, one shown too early spoils the card.
class KhaamOpenedIds extends AsyncNotifier<Set<String>> {
  @override
  Future<Set<String>> build() => ref.read(khaamOpenedStoreProvider).all();

  Future<void> markOpened(String id) async {
    final now = state.valueOrNull ?? const <String>{};
    if (!now.contains(id)) state = AsyncData({...now, id});
    await ref.read(khaamOpenedStoreProvider).markOpened(id);
  }
}

final khaamOpenedIdsProvider =
    AsyncNotifierProvider<KhaamOpenedIds, Set<String>>(KhaamOpenedIds.new);

/// Whether [id] is opened here; false while the store is still loading.
bool khaamIsOpened(Set<String>? ids, String id) => ids?.contains(id) ?? false;

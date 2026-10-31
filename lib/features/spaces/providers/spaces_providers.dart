import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../auth/providers/auth_provider.dart';
import '../../messages/providers/chat_provider.dart';
import '../data/space_api.dart';
import '../data/space_backend.dart';
import '../data/space_cache.dart';
import '../data/space_loader.dart';
import '../data/space_models.dart';

export '../data/space_backend.dart';
export 'space_selection.dart';

/// Changes on every sign-in / sign-out. Everything in Spaces watches it, so
/// an account switch drops the old account's rail, channels and messages from memory instead of carrying them into the new account.
final spaceSessionProvider = Provider<Object?>(
  (ref) => ref.watch(authProvider).valueOrNull,
);

final spacesBackendProvider = Provider<SpacesBackend>((ref) {
  ref.watch(spaceSessionProvider);
  return SpaceApi(dio: ref.watch(apiClientProvider).dio);
});

final spaceKvProvider = Provider<SpaceKv>((ref) => PrefsSpaceKv());

/// The signed-in account, which every cache key is scoped to.
final spaceAccountProvider = FutureProvider<String>((ref) {
  ref.watch(spaceSessionProvider);
  return ref.read(chatProvider.notifier).ensureCurrentUserId();
});

Future<SpaceCache> spaceCacheOf(Ref ref) async => SpaceCache(
  ref.read(spaceKvProvider),
  await ref.read(spaceAccountProvider.future),
);

class SpacesListNotifier extends Notifier<SpaceLoad<List<SpaceSummary>>> {
  late SpaceLoader<List<SpaceSummary>> _loader;

  @override
  SpaceLoad<List<SpaceSummary>> build() {
    ref.watch(spaceSessionProvider);
    _loader = SpaceLoader(
      readCache: () async => (await spaceCacheOf(ref)).readList(),
      writeCache: (v) async => (await spaceCacheOf(ref)).writeList(v),
      fetch: () => ref.read(spacesBackendProvider).listSpaces(),
      onState: (s) => state = s,
    );
    ref.onDispose(_loader.dispose);
    Future.microtask(_loader.load);
    return const SpaceLoad(loading: true);
  }

  Future<void> refresh() => _loader.refresh();
}

final spacesListProvider =
    NotifierProvider<SpacesListNotifier, SpaceLoad<List<SpaceSummary>>>(
      SpacesListNotifier.new,
    );

class SpaceTreeNotifier extends FamilyNotifier<SpaceLoad<SpaceTree>, String> {
  late SpaceLoader<SpaceTree> _loader;

  @override
  SpaceLoad<SpaceTree> build(String spaceId) {
    ref.watch(spaceSessionProvider);
    _loader = SpaceLoader(
      readCache: () async => (await spaceCacheOf(ref)).readTree(spaceId),
      writeCache: (v) async => (await spaceCacheOf(ref)).writeTree(v),
      fetch: () => ref.read(spacesBackendProvider).channels(spaceId),
      onState: (s) => state = s,
    );
    ref.onDispose(_loader.dispose);
    Future.microtask(_loader.load);
    return const SpaceLoad(loading: true);
  }

  Future<void> refresh() => _loader.refresh();
}

final spaceTreeProvider =
    NotifierProvider.family<SpaceTreeNotifier, SpaceLoad<SpaceTree>, String>(
      SpaceTreeNotifier.new,
    );

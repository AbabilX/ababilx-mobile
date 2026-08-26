import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/first_load_timeout.dart';
import '../../../core/session/authenticated_fetch.dart';
import '../data/profile_media_repository.dart';
import '../data/profile_repository.dart';

class ProfileNotifier extends AsyncNotifier<AppUser> {
  @override
  Future<AppUser> build() => fetchWhenAuthenticated(ref, () async {
    final repo = ref.read(profileRepositoryProvider);
    final cached = await repo.getCachedMe();
    if (cached != null) {
      // WhatsApp-style: paint the cached profile immediately — cold
      // opening the app must never sit waiting on the network — then
      // refresh over the network in the background.
      unawaited(_refreshInBackground(repo));
      return cached;
    }
    // First-ever load, nothing cached yet: this has to wait — but not out
    // Dio's full connect+receive timeout on a weak/dead connection.
    return repo.getMe().timeout(firstLoadNetworkTimeout);
  });

  Future<void> _refreshInBackground(ProfileRepository repo) async {
    try {
      final fresh = await repo.getMe();
      state = AsyncData(fresh);
    } catch (_) {
      // Offline or the request failed — the cached profile already on
      // screen stays put.
    }
  }

  Future<void> refresh() async {
    final prev = state.valueOrNull;
    try {
      final user = await ref.read(profileRepositoryProvider).getMe();
      state = AsyncData(user);
    } catch (e, st) {
      if (prev != null) {
        state = AsyncData(prev);
      } else {
        final cached = await ref.read(profileRepositoryProvider).getCachedMe();
        if (cached != null) {
          state = AsyncData(cached);
        } else {
          state = AsyncError(e, st);
        }
      }
    }
  }

  Future<void> updateLanguage(String lang) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(profileRepositoryProvider).updateLanguage(lang),
    );
  }

  /// Renames the account. Optimistic: the value the server stored lands in
  /// state and in the offline cache immediately, because this is the one field
  /// the user is staring at while they save it.
  ///
  /// Throws on failure so the edit screen can keep the field open with the
  /// server's reason instead of silently discarding what was typed.
  Future<void> updateName(String name) async {
    final repo = ref.read(profileRepositoryProvider);
    final stored = await repo.updateName(name);
    final current = state.valueOrNull;
    if (current == null) {
      await refresh();
      return;
    }
    final updated = current.copyWith(name: stored);
    state = AsyncData(updated);
    await repo.cacheUser(updated);
  }

  /// Uploads a new avatar and shows it immediately.
  ///
  /// Optimistic for the same reason [updateName] is: the user is looking
  /// straight at the picture they just cropped, and waiting a round trip for
  /// GET /api/me before it changes reads as a failed save.
  ///
  /// Throws on failure so the caller can surface the reason.
  Future<void> updateAvatar(Uint8List bytes) async {
    final media = ref.read(profileMediaRepositoryProvider);
    final target = await media.presign(kind: 'avatar', contentType: 'image/png');
    if (!target.isValid) {
      throw StateError('Server did not return an upload URL');
    }
    await media.upload(target, bytes, 'image/png');
    await media.saveAvatar(target.publicUrl);

    final current = state.valueOrNull;
    if (current == null) {
      await refresh();
      return;
    }
    final updated = current.copyWith(avatarUrl: target.publicUrl);
    state = AsyncData(updated);
    await ref.read(profileRepositoryProvider).cacheUser(updated);
  }

  Future<void> acceptPolicy() async {
    final current = state.valueOrNull;
    await ref.read(profileRepositoryProvider).acceptPolicy();
    if (current != null) {
      state = AsyncData(current.copyWith(acceptPolicy: true));
    }
  }
}

final profileProvider = AsyncNotifierProvider<ProfileNotifier, AppUser>(
  ProfileNotifier.new,
);

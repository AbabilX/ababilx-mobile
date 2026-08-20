import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/first_load_timeout.dart';
import '../../../core/session/authenticated_fetch.dart';
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

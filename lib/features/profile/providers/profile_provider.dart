import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/session/authenticated_fetch.dart';
import '../data/profile_repository.dart';

class ProfileNotifier extends AsyncNotifier<AppUser> {
  @override
  Future<AppUser> build() => fetchWhenAuthenticated(
        ref,
        () => ref.read(profileRepositoryProvider).getMe(),
      );

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(profileRepositoryProvider).getMe(),
    );
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

final profileProvider =
    AsyncNotifierProvider<ProfileNotifier, AppUser>(ProfileNotifier.new);

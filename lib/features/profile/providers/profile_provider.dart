import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/profile_repository.dart';

class ProfileNotifier extends AsyncNotifier<AppUser> {
  @override
  Future<AppUser> build() =>
      ref.read(profileRepositoryProvider).getMe();

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
}

final profileProvider =
    AsyncNotifierProvider<ProfileNotifier, AppUser>(ProfileNotifier.new);

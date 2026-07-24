import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../messages/data/local/chat_sidebar_cache.dart';
import '../../messages/providers/chat_provider.dart';
import '../data/auth_repository.dart';

/// Auth state — null = logged out / unknown, String = user id or JWT marker.
/// GoRouter redirect checks this to decide whether to show login.
class AuthNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final token = await ref.read(authRepositoryProvider).readToken();
    return token != null;
  }

  Future<void> signInWithGoogle() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(authRepositoryProvider).signInWithGoogle();
      return true;
    });
  }

  Future<void> signOut() async {
    // Clear chat disk cache so next account never sees prior sidebar.
    try {
      await ref.read(chatSidebarCacheProvider).clearAll();
    } catch (_) {}
    ref.read(chatProvider.notifier).resetTeamChatState();
    await ref.read(authRepositoryProvider).signOut();
    state = const AsyncData(false);
  }
}

final authProvider =
    AsyncNotifierProvider<AuthNotifier, bool>(AuthNotifier.new);

/// Convenience — true if authenticated.
final isAuthenticatedProvider = Provider<bool>(
  (ref) => ref.watch(authProvider).valueOrNull ?? false,
);

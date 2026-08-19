import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../messages/data/local/chat_feed_cache.dart';
import '../../messages/data/local/chat_outbox_cache.dart';
import '../../messages/data/local/chat_sidebar_cache.dart';
import '../../messages/message_e2ee/message_vault.dart';
import '../../messages/providers/chat_provider.dart';
import '../../notifications/providers/fcm_provider.dart';
import '../../profile/data/profile_repository.dart';
import '../../team/data/team_repository.dart';
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
    // Deregister FCM while JWT is still valid.
    try {
      await ref.read(fcmServiceProvider).stopAndDeregister();
    } catch (_) {}
    ref.read(notificationPermissionProvider.notifier).setGranted(false);

    // Clear chat disk cache so next account never sees prior sidebar or feeds.
    try {
      await ref.read(chatSidebarCacheProvider).clearAll();
      await ref.read(chatFeedCacheProvider).clearAll();
      // An unsent outbox message is scoped to this account's identity (and,
      // for channels, plain text) — it must not survive into a different
      // account signed in on this device, same as the caches above.
      await ref.read(chatOutboxCacheProvider).clearAll();
    } catch (_) {}
    // Same reason: the offline profile/team cache must not leak into the next
    // account signed in on this device.
    try {
      await ref.read(profileRepositoryProvider).clearCache();
      await ref.read(teamRepositoryProvider).clearCache();
    } catch (_) {}
    ref.read(messageVaultProvider).lock();
    ref.read(chatProvider.notifier).resetTeamChatState(clearCurrentUser: true);
    await ref.read(authRepositoryProvider).signOut();
    state = const AsyncData(false);
  }
}

final authProvider = AsyncNotifierProvider<AuthNotifier, bool>(
  AuthNotifier.new,
);

/// Convenience — true if authenticated.
final isAuthenticatedProvider = Provider<bool>(
  (ref) => ref.watch(authProvider).valueOrNull ?? false,
);

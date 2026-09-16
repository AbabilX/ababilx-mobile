import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../attachments/providers/attachment_providers.dart';
import '../../messages/message_e2ee/message_entry_quiet.dart';
import '../../messages/message_e2ee/message_vault.dart';
import '../../messages/archive/archive_provider.dart';
import '../../messages/message_e2ee/new_chat_setup.dart';
import '../../messages/providers/chat_provider.dart';
import '../../notifications/chat/chat_notification_store.dart';
import '../../notifications/providers/fcm_provider.dart';
import '../../profile/data/profile_repository.dart';
import '../../../core/network/api_client.dart';
import '../data/account_data_wiper.dart';
import '../data/auth_repository.dart';
import '../data/auth_session.dart';

/// Auth state — null = logged out / unknown, String = user id or JWT marker.
/// GoRouter redirect checks this to decide whether to show login.
class AuthNotifier extends AsyncNotifier<bool> {
  PreparedAuthSession? _pendingSession;

  @override
  Future<bool> build() async {
    final token = await ref.read(authRepositoryProvider).readToken();
    if (token == null) return false;
    await _bootstrapLegacyOwner();
    // Decided before auth resolves, so a returning launch routes straight to
    // chats instead of passing through the message check screen.
    await tryQuietMessageEntry(ref);
    return true;
  }

  Future<GoogleSignInOutcome> signInWithGoogle() async {
    state = const AsyncLoading();
    try {
      final repo = ref.read(authRepositoryProvider);
      final session = await repo.prepareGoogleSignIn();
      if (session == null) {
        state = const AsyncData(false);
        return const GoogleSignInCancelled();
      }
      final storage = ref.read(secureStorageProvider);
      final cached = await ref.read(profileRepositoryProvider).getCachedMe();
      final storedOwner = await storage.readLocalDataOwnerUserId();
      final hasUnownedPrivateData =
          (storedOwner?.trim().isEmpty ?? true) &&
          ((await storage.readMessageVaultIdentity())?.isNotEmpty ?? false);
      final decision = decideLocalAccount(
        newUserId: session.userId,
        storedOwnerUserId: storedOwner,
        cachedOwnerUserId: cached?.id,
        hasUnownedPrivateData: hasUnownedPrivateData,
      );
      if (decision == LocalAccountDecision.switchAccount) {
        _pendingSession = session;
        state = const AsyncData(false);
        return GoogleAccountSwitchRequired(session.accountLabel);
      }
      await repo.commitSession(session);
      _pendingSession = null;
      state = const AsyncData(true);
      return const GoogleSignInSucceeded();
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return GoogleSignInFailed(error);
    }
  }

  Future<GoogleSignInOutcome> confirmAccountSwitch() async {
    final session = _pendingSession;
    if (session == null) {
      final error = StateError('No account switch is waiting');
      state = AsyncError(error, StackTrace.current);
      return GoogleSignInFailed(error);
    }
    state = const AsyncLoading();
    try {
      await ref.read(accountDataWiperProvider).clear();
      await ref.read(authRepositoryProvider).commitSession(session);
      _pendingSession = null;
      ref.invalidate(archiveProvider);
      state = const AsyncData(true);
      return const GoogleSignInSucceeded();
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return GoogleSignInFailed(error);
    }
  }

  Future<void> cancelAccountSwitch() async {
    _pendingSession = null;
    await ref.read(authRepositoryProvider).cancelPreparedSignIn();
    state = const AsyncData(false);
  }

  Future<void> _bootstrapLegacyOwner() async {
    final storage = ref.read(secureStorageProvider);
    final owner = await storage.readLocalDataOwnerUserId();
    if (owner != null && owner.trim().isNotEmpty) return;
    final cached = await ref.read(profileRepositoryProvider).getCachedMe();
    final userId = cached?.id.trim() ?? '';
    if (userId.isNotEmpty) await storage.writeLocalDataOwnerUserId(userId);
  }

  Future<void> signOut() async {
    ref.read(newChatSetupProvider.notifier).reset();
    await ref.read(archiveProvider.notifier).cancel();
    await ref.read(chatProvider.notifier).cancelHistoryRestore();
    await ref.read(messageVaultProvider).cancelRecoverySession();
    // Deregister FCM while JWT is still valid.
    try {
      await ref.read(fcmServiceProvider).stopAndDeregister();
    } catch (_) {}
    ref.read(notificationPermissionProvider.notifier).setGranted(false);
    await ChatNotificationStore.clearAll();
    await ref.read(localNotificationsProvider).cancelAll();

    // Stop work from this session, but keep this phone's Signal-style archive.
    try {
      await ref.read(attachmentQueueProvider).cancelAll();
      ref.invalidate(attachmentAuthorityProvider);
      ref.invalidate(attachmentQueueProvider);
    } catch (_) {}
    ref.read(messageVaultProvider).lock();
    ref.read(chatProvider.notifier).resetTeamChatState(clearCurrentUser: true);
    await ref.read(authRepositoryProvider).signOut();
    _pendingSession = null;
    ref.invalidate(archiveProvider);
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

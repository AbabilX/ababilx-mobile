import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../attachments/providers/attachment_providers.dart';
import '../../messages/message_e2ee/message_entry_quiet.dart';
import '../../messages/message_e2ee/message_vault.dart';
import '../../messages/archive/archive_provider.dart';
import '../../messages/message_e2ee/new_chat_setup.dart';
import '../../messages/providers/chat_provider.dart';
import '../../notifications/chat/chat_notification_store.dart';
import '../../notifications/chat/chat_notification_dismissals.dart';
import '../../notifications/providers/fcm_provider.dart';
import '../../profile/data/profile_repository.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/friendly_error.dart';
import '../data/account_data_wiper.dart';
import '../data/auth_repository.dart';
import '../data/auth_session.dart';
import '../device/device_account_key.dart';
import '../device/device_auth_repository.dart';

/// Auth state — null = logged out / unknown, String = user id or JWT marker.
/// GoRouter redirect checks this to decide whether to show login.
class AuthNotifier extends AsyncNotifier<bool> {
  PreparedAuthSession? _pendingSession;

  @override
  Future<bool> build() async {
    var token = await ref.read(authRepositoryProvider).readToken();
    // A key-only account whose session was dropped is signed back in by its
    // key rather than parked on the login screen, where "Start New Chat"
    // would replace it.
    if (token == null &&
        await ref.read(authRepositoryProvider).hasAccountKey()) {
      await ref.read(apiClientProvider).ensureFreshAccessToken();
      token = await ref.read(authRepositoryProvider).readToken();
    }
    if (token == null) return false;
    await _bootstrapLegacyOwner();
    // Decided before auth resolves, so a returning launch routes straight to
    // chats instead of passing through the message check screen.
    await tryQuietMessageEntry(ref);
    return true;
  }

  Future<SignInOutcome> signInWithGoogle() async {
    state = const AsyncLoading();
    try {
      final session = await ref
          .read(authRepositoryProvider)
          .prepareGoogleSignIn();
      if (session == null) {
        state = const AsyncData(false);
        return const SignInCancelled();
      }
      return await _adopt(session);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return SignInFailed(error);
    }
  }

  /// "Start New Chat": a brand-new account with no email, Google, phone or
  /// name. The phone makes its key, the server makes the id. Goes through
  /// [_adopt], so another account's data on this phone is never replaced
  /// without the usual question.
  Future<SignInOutcome> startNewChat() async {
    state = const AsyncLoading();
    try {
      final key = await DeviceAccountKey.generate();
      final session = await ref
          .read(deviceAuthRepositoryProvider)
          .register(key);
      return await _adopt(session);
    } catch (error, stackTrace) {
      // The server's own sentence when it gave one, else offline/timeout copy
      // rather than a DioException dump on the login screen.
      final shown = error is DioException
          ? Exception(friendlyErrorMessage(error))
          : error;
      state = AsyncError(shown, stackTrace);
      return SignInFailed(error);
    }
  }

  /// Finishes a sign-in the server already accepted (email + password, or a
  /// confirmed code). The email screens own their own errors, so a failure
  /// here is reported through the outcome and never parks the login screen
  /// in an error state.
  Future<SignInOutcome> signInWithSession(PreparedAuthSession session) async {
    state = const AsyncLoading();
    try {
      return await _adopt(session);
    } catch (error) {
      state = const AsyncData(false);
      return SignInFailed(error);
    }
  }

  /// Commits [session], unless this phone holds another account's private
  /// data — then the switch waits for the user's confirmation, whichever way
  /// they signed in.
  Future<SignInOutcome> _adopt(PreparedAuthSession session) async {
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
      return AccountSwitchRequired(session.accountLabel);
    }
    await ref.read(authRepositoryProvider).commitSession(session);
    _pendingSession = null;
    state = const AsyncData(true);
    return const SignInSucceeded();
  }

  Future<SignInOutcome> confirmAccountSwitch() async {
    final session = _pendingSession;
    if (session == null) {
      final error = StateError('No account switch is waiting');
      state = AsyncError(error, StackTrace.current);
      return SignInFailed(error);
    }
    state = const AsyncLoading();
    try {
      await ref.read(accountDataWiperProvider).clear();
      await ref.read(authRepositoryProvider).commitSession(session);
      _pendingSession = null;
      ref.invalidate(archiveProvider);
      state = const AsyncData(true);
      return const SignInSucceeded();
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return SignInFailed(error);
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

  /// Deletes the account on the server, then ends the session and wipes
  /// everything it left on this phone. Throws if the server refuses, with the
  /// session untouched. [onDeleted] runs between the two: whatever is on
  /// screen (the confirm sheet) must close BEFORE sign-out sends the router to
  /// /login, or its pop lands on the login page and leaves a black screen.
  Future<void> deleteAccount({void Function()? onDeleted}) async {
    await ref.read(authRepositoryProvider).deleteAccount();
    onDeleted?.call();
    await signOut();
    await ref.read(accountDataWiperProvider).clear();
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
    await ChatNotificationDismissals.clearAll();
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

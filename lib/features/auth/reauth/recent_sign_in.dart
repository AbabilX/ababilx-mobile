import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/recent_sign_in.dart';
import '../../../core/storage/secure_storage.dart';
import '../../profile/providers/profile_provider.dart';
import '../data/auth_repository.dart';
import '../data/auth_session.dart';
import '../device/device_relogin.dart';

/// Signs this phone in again, for real, when the server wants a recent
/// sign-in (403 recent_sign_in_required). A refresh would not do: it keeps
/// the old session, and the server measures from the sign-in.
///
/// Only the auth tokens change. The message identity, its keys, the archive
/// and backups are never read or written here, and nothing here creates or
/// replaces an identity. It signs in only as the account this phone's data
/// belongs to; any other account is refused and its new session ended.
class RecentSignIn {
  RecentSignIn({
    required this.storage,
    required this.bareDio,
    required this.keyRelogin,
    required this.googleSignIn,
    required this.accountProvider,
  });

  final SecureStorage storage;
  final Dio bareDio;
  final Future<RefreshOutcome> Function() keyRelogin;
  final Future<PreparedAuthSession?> Function() googleSignIn;
  final Future<String> Function() accountProvider;
  Future<ReauthOutcome>? _inFlight;

  /// One attempt at a time: two refusals at once ask the person once.
  Future<ReauthOutcome> reauthenticate() {
    return _inFlight ??= _run().whenComplete(() {
      _inFlight = null;
    });
  }

  Future<ReauthOutcome> _run() async {
    final previous = await storage.readRefreshToken();
    final outcome = await _signIn();
    // The new sign-in replaces this phone's session; the old one is ended
    // so it does not linger in Linked devices with a token nobody holds.
    if (outcome == ReauthOutcome.signedIn) await _retire(previous);
    return outcome;
  }

  Future<ReauthOutcome> _signIn() async {
    // A key-only account ("Start New Chat"): its key on this phone IS its
    // sign-in, a fresh challenge signed by it.
    if ((await storage.readAccountKey())?.isNotEmpty == true) {
      return switch (await keyRelogin()) {
        RefreshOutcome.refreshed => ReauthOutcome.signedIn,
        RefreshOutcome.rejected => ReauthOutcome.failed,
        RefreshOutcome.unavailable => ReauthOutcome.unavailable,
      };
    }
    final provider = await accountProvider();
    // No password is kept on the phone; and a key-only account without its
    // key cannot sign in at all.
    if (provider == 'email') return ReauthOutcome.notSupported;
    if (provider == 'device') return ReauthOutcome.failed;
    return _google();
  }

  Future<ReauthOutcome> _google() async {
    final PreparedAuthSession? session;
    try {
      session = await googleSignIn();
    } on PlatformException catch (error) {
      if (error.code == 'sign_in_canceled') return ReauthOutcome.cancelled;
      if (error.code == 'network_error') return ReauthOutcome.unavailable;
      return ReauthOutcome.failed;
    } on DioException catch (error) {
      return refreshOutcomeForStatus(error.response?.statusCode) ==
              RefreshOutcome.rejected
          ? ReauthOutcome.failed
          : ReauthOutcome.unavailable;
    } catch (_) {
      return ReauthOutcome.failed;
    }
    if (session == null) return ReauthOutcome.cancelled;
    final owner = (await storage.readLocalDataOwnerUserId())?.trim() ?? '';
    final refresh = session.refreshToken ?? '';
    if (owner.isEmpty || session.userId != owner || refresh.isEmpty) {
      // A different Google account: never switch accounts from here.
      await _retire(refresh);
      return ReauthOutcome.failed;
    }
    await storage.writeRefreshToken(refresh);
    // Access token last, as AuthRepository.commitSession writes it.
    await storage.writeJwt(session.accessToken);
    return ReauthOutcome.signedIn;
  }

  /// Ends a session by its refresh token. Best effort: a session left behind
  /// expires with its token.
  Future<void> _retire(String? refreshToken) async {
    if (refreshToken == null || refreshToken.isEmpty) return;
    try {
      await bareDio.post(
        ApiConstants.authLogout,
        data: {'refresh_token': refreshToken},
      );
    } catch (_) {}
  }
}

final recentSignInProvider = Provider<RecentSignIn>((ref) {
  final client = ref.watch(apiClientProvider);
  final storage = ref.watch(secureStorageProvider);
  return RecentSignIn(
    storage: storage,
    bareDio: client.bareDio,
    keyRelogin: () => reloginWithAccountKey(client.bareDio, storage),
    googleSignIn: () async {
      final idToken = await ref.read(authRepositoryProvider).googleIdToken();
      if (idToken == null) return null;
      // Bare: a refused token must not reach the 401 handler, which would
      // end the session this sign-in is meant to renew.
      final response = await client.bareDio.post(
        ApiConstants.mobileGoogleAuth,
        data: {'id_token': idToken},
      );
      return PreparedAuthSession.fromLoginBody(
        Map<String, dynamic>.from(response.data as Map),
      );
    },
    accountProvider: () async =>
        ref.read(profileProvider).valueOrNull?.provider ?? '',
  );
});

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../../core/network/api_client.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/storage/secure_storage.dart';
import '../../../firebase_options.dart';
import 'auth_session.dart';

class AuthRepository {
  AuthRepository(this._client, this._storage);

  final ApiClient _client;
  final SecureStorage _storage;

  final _googleSignIn = GoogleSignIn(
    serverClientId: DefaultFirebaseOptions.googleWebClientId,
    scopes: ['email', 'profile'],
  );
  final _firebaseAuth = FirebaseAuth.instance;

  /// Sign in with Google via Firebase Auth.
  ///
  /// Flow:
  ///   1. Google Sign-In → get Google credentials
  ///   2. Sign into Firebase with those credentials
  ///   3. Get Google ID token → send to our backend → receive app JWT
  Future<PreparedAuthSession?> prepareGoogleSignIn() async {
    // Disconnect any cached account to force a fresh account picker
    // and ensure a valid idToken is issued every time.
    await _googleSignIn.signOut();

    // Trigger Google Sign-In picker
    final googleAccount = await _googleSignIn.signIn();
    if (googleAccount == null) return null;

    final googleAuth = await googleAccount.authentication;
    final accessToken = googleAuth.accessToken;
    String? idToken = googleAuth.idToken;

    // Sign into Firebase (validates credentials + links account)
    final credential = GoogleAuthProvider.credential(
      idToken: idToken,
      accessToken: accessToken,
    );
    final userCredential = await _firebaseAuth.signInWithCredential(credential);

    // Fallback: get idToken from Firebase if Google didn't return one.
    // This can happen when the account is already cached.
    idToken ??= await userCredential.user?.getIdToken();

    if (idToken == null) {
      throw Exception(
        'No ID token — check SHA-1 fingerprint in Firebase console',
      );
    }

    // Exchange Google ID token for our app JWT
    final response = await _client.post(
      ApiConstants.mobileGoogleAuth,
      data: {'id_token': idToken},
    );

    return PreparedAuthSession.fromLoginBody(
      response.data as Map<String, dynamic>,
    );
  }

  /// The access token is written last. A partial write can therefore never
  /// make the router treat an unowned or half-switched session as signed in.
  Future<void> commitSession(PreparedAuthSession session) async {
    try {
      final refresh = session.refreshToken;
      if (refresh == null || refresh.isEmpty) {
        await _storage.deleteRefreshToken();
      } else {
        await _storage.writeRefreshToken(refresh);
      }
      // A Google/email sign-in drops any leftover account key, so a refused
      // refresh can never sign this phone into a different account.
      final seed = session.accountKeySeed;
      if (seed == null) {
        await _storage.deleteAccountKey();
      } else {
        await _storage.writeAccountKey(seed);
      }
      await _storage.writeLocalDataOwnerUserId(session.userId);
      await _storage.writeJwt(session.accessToken);
    } catch (_) {
      await _storage.clearAuthSession();
      rethrow;
    }
  }

  Future<void> cancelPreparedSignIn() async {
    try {
      await _firebaseAuth.signOut();
    } catch (_) {}
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
    await _storage.clearAuthSession();
  }

  /// Ending the local session is the part that must not fail. Firebase and
  /// Google are asked first but never allowed to abort it — a plugin error or
  /// a dead network would otherwise leave the JWT on disk, and the app comes
  /// back up still signed in with a sign-out the user believes happened.
  ///
  /// A key-only account's key goes too: signing out of one is final, and the
  /// next "Start New Chat" is a new account (user's decision, 2026-10-20).
  Future<void> signOut() async {
    try {
      await _firebaseAuth.signOut();
    } catch (_) {}
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
    await _storage.deleteAccountKey();
    await _storage.clearAuthSession();
  }

  /// Deletes the account on the server for good. Throws on refusal, so the
  /// caller keeps the session and says why.
  Future<void> deleteAccount() async {
    await _client.delete<dynamic>(ApiConstants.meDeleteAccount);
  }

  /// True while this phone is signed in with a key-only account.
  Future<bool> hasAccountKey() async =>
      (await _storage.readAccountKey())?.isNotEmpty ?? false;

  Future<String?> readToken() => _storage.readJwt();
}

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(
    ref.watch(apiClientProvider),
    ref.watch(secureStorageProvider),
  ),
);

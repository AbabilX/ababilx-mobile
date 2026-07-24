import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../../core/network/api_client.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/storage/secure_storage.dart';
import '../../../firebase_options.dart';

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
  Future<Map<String, dynamic>> signInWithGoogle() async {
    // Disconnect any cached account to force a fresh account picker
    // and ensure a valid idToken is issued every time.
    await _googleSignIn.signOut();

    // Trigger Google Sign-In picker
    final googleAccount = await _googleSignIn.signIn();
    if (googleAccount == null) throw Exception('Google sign-in cancelled');

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

    final body = response.data as Map<String, dynamic>;
    if (body['success'] != true) {
      throw Exception(body['error']?.toString() ?? 'Login failed');
    }

    final jwt = body['access_token'] as String? ??
        body['token'] as String? ??
        body['data']?['token'] as String?;
    if (jwt == null) throw Exception('No token in server response');

    final refreshToken = body['refresh_token'] as String?;
    await _storage.writeJwt(jwt);
    if (refreshToken != null) {
      await _storage.writeRefreshToken(refreshToken);
    }

    final user = body['user'] as Map<String, dynamic>?;
    return user ?? {};
  }

  Future<void> signOut() async {
    await _firebaseAuth.signOut();
    await _googleSignIn.signOut();
    await _storage.clearAll();
  }

  Future<String?> readToken() => _storage.readJwt();
}

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(
    ref.watch(apiClientProvider),
    ref.watch(secureStorageProvider),
  ),
);

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../../core/network/api_client.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/storage/secure_storage.dart';

/// Google OAuth Client ID from Firebase project (web client ID used as serverClientId).
/// This ensures the ID token is scoped to the backend's client.
const _webClientId =
    '554025641104-v2kvaaisco9adphuo13g0c3ej5rkvq2b.apps.googleusercontent.com';

class AuthRepository {
  AuthRepository(this._client, this._storage);

  final ApiClient _client;
  final SecureStorage _storage;

  final _googleSignIn = GoogleSignIn(serverClientId: _webClientId);

  /// Sign in with Google → exchange ID token for app JWT → register FCM token.
  Future<Map<String, dynamic>> signInWithGoogle() async {
    final account = await _googleSignIn.signIn();
    if (account == null) throw Exception('Google sign-in cancelled');

    final auth = await account.authentication;
    final idToken = auth.idToken;
    if (idToken == null) throw Exception('No ID token received from Google');

    final response = await _client.post(
      ApiConstants.mobileGoogleAuth,
      data: {'id_token': idToken},
    );

    final body = response.data as Map<String, dynamic>;
    final jwt = body['token'] as String? ?? body['data']?['token'] as String?;
    if (jwt == null) throw Exception('No token in server response');

    await _storage.writeJwt(jwt);

    // Register device FCM token with backend
    final fcmToken = await FirebaseMessaging.instance.getToken();
    if (fcmToken != null) {
      await _storage.writeFcmToken(fcmToken);
      await _registerDevice(fcmToken);
    }

    final user = body['user'] as Map<String, dynamic>?;
    return user ?? {};
  }

  /// Register FCM token with backend so it can receive push notifications.
  Future<void> _registerDevice(String fcmToken) async {
    try {
      await _client.post(
        ApiConstants.devices,
        data: {'fcm_token': fcmToken, 'platform': 'android'},
      );
    } catch (_) {
      // Non-fatal — continue without push if registration fails
    }
  }

  /// Re-register FCM token (called on token refresh).
  Future<void> refreshDeviceToken(String newToken) async {
    await _storage.writeFcmToken(newToken);
    await _registerDevice(newToken);
  }

  /// Sign out — deregister FCM token, clear JWT, sign out Google.
  Future<void> signOut() async {
    // Deregister FCM token
    try {
      final fcmToken = await _storage.readFcmToken();
      if (fcmToken != null) {
        await _client.delete(
          ApiConstants.devices,
          data: {'fcm_token': fcmToken},
        );
      }
    } catch (_) {
      // Non-fatal
    }

    await _googleSignIn.signOut();
    await _storage.clearAll();
  }

  /// Check if a JWT is stored (used on app start to determine auth state).
  Future<String?> readToken() => _storage.readJwt();
}

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(
    ref.watch(apiClientProvider),
    ref.watch(secureStorageProvider),
  ),
);

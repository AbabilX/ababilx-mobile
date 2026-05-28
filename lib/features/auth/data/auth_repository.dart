import 'dart:io' show Platform;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
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
  );
  final _firebaseAuth = FirebaseAuth.instance;

  /// Sign in with Google via Firebase Auth.
  ///
  /// Flow:
  ///   1. Google Sign-In → get Google credentials
  ///   2. Sign into Firebase with those credentials
  ///   3. Get Google ID token → send to our backend → receive app JWT
  Future<Map<String, dynamic>> signInWithGoogle() async {
    // Trigger Google Sign-In picker
    final googleAccount = await _googleSignIn.signIn();
    if (googleAccount == null) throw Exception('Google sign-in cancelled');

    final googleAuth = await googleAccount.authentication;
    final idToken = googleAuth.idToken;
    final accessToken = googleAuth.accessToken;

    if (idToken == null) throw Exception('No ID token from Google');

    // Sign into Firebase (validates credentials + links account)
    final credential = GoogleAuthProvider.credential(
      idToken: idToken,
      accessToken: accessToken,
    );
    await _firebaseAuth.signInWithCredential(credential);

    // Exchange Google ID token for our app JWT
    final response = await _client.post(
      ApiConstants.mobileGoogleAuth,
      data: {'id_token': idToken},
    );

    final body = response.data as Map<String, dynamic>;
    final jwt = body['token'] as String? ?? body['data']?['token'] as String?;
    if (jwt == null) throw Exception('No token in server response');

    await _storage.writeJwt(jwt);

    // Register FCM token
    final fcmToken = await FirebaseMessaging.instance.getToken();
    if (fcmToken != null) {
      await _storage.writeFcmToken(fcmToken);
      await _registerDevice(fcmToken);
    }

    final user = body['user'] as Map<String, dynamic>?;
    return user ?? {};
  }

  Future<void> _registerDevice(String fcmToken) async {
    try {
      final platformStr = Platform.isIOS ? 'ios' : 'android';
      await _client.post(
        ApiConstants.devices,
        data: {'fcm_token': fcmToken, 'platform': platformStr},
      );
    } catch (_) {}
  }

  Future<void> refreshDeviceToken(String newToken) async {
    await _storage.writeFcmToken(newToken);
    await _registerDevice(newToken);
  }

  Future<void> signOut() async {
    try {
      final fcmToken = await _storage.readFcmToken();
      if (fcmToken != null) {
        await _client.delete(ApiConstants.devices, data: {'fcm_token': fcmToken});
      }
    } catch (_) {}

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

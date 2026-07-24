/// Base URL for the AbabilX backend.
/// Change to production URL for release builds.
class ApiConstants {
  ApiConstants._();

  static const String baseUrl = 'https://api.ababilx.cloud';

  // Auth
  static const String mobileGoogleAuth = '/auth/google/mobile';
  static const String authRefresh = '/auth/refresh';

  // User (split me API — merge in ProfileRepository.getMe)
  static const String me = '/api/me';
  static const String meProfile = '/api/me/profile';
  static const String mePlan = '/api/me/plan';
  static const String meConnections = '/api/me/connections';
}

/// Secure storage keys.
class StorageKeys {
  StorageKeys._();

  static const String jwt = 'ababilx_jwt';
  static const String refreshToken = 'ababilx_refresh_token';
}

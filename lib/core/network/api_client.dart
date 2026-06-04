import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/api_constants.dart';
import '../storage/secure_storage.dart';

/// Global Dio instance with JWT injection and 401 refresh handling.
class ApiClient {
  ApiClient(this._storage) {
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
        headers: {'Content-Type': 'application/json'},
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _storage.readJwt();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          if (error.response?.statusCode != 401) {
            handler.next(error);
            return;
          }

          final path = error.requestOptions.path;
          if (path == ApiConstants.authRefresh ||
              error.requestOptions.extra['retried'] == true) {
            await _storage.clearAll();
            handler.next(error);
            return;
          }

          final refreshed = await _tryRefreshToken();
          if (!refreshed) {
            await _storage.clearAll();
            handler.next(error);
            return;
          }

          final token = await _storage.readJwt();
          final opts = error.requestOptions;
          opts.headers['Authorization'] = 'Bearer $token';
          opts.extra['retried'] = true;

          try {
            final response = await _dio.fetch(opts);
            handler.resolve(response);
          } catch (e) {
            handler.next(e is DioException ? e : error);
          }
        },
      ),
    );
  }

  late final Dio _dio;
  final SecureStorage _storage;
  Future<bool>? _refreshInFlight;

  Future<bool> _tryRefreshToken() {
    _refreshInFlight ??= _refreshAccessToken().whenComplete(() {
      _refreshInFlight = null;
    });
    return _refreshInFlight!;
  }

  Future<bool> _refreshAccessToken() async {
    final refreshToken = await _storage.readRefreshToken();
    if (refreshToken == null) return false;

    try {
      final response = await _dio.post(
        ApiConstants.authRefresh,
        data: {'refresh_token': refreshToken},
      );
      final body = response.data as Map<String, dynamic>?;
      if (body == null || body['success'] != true) return false;

      final access = (body['access_token'] ?? body['token']) as String?;
      final nextRefresh = (body['refresh_token'] ?? refreshToken) as String;
      if (access == null) return false;

      await _storage.writeJwt(access);
      await _storage.writeRefreshToken(nextRefresh);
      return true;
    } catch (_) {
      return false;
    }
  }

  Dio get dio => _dio;

  Future<Response<T>> get<T>(String path,
          {Map<String, dynamic>? queryParameters}) =>
      _dio.get<T>(path, queryParameters: queryParameters);

  Future<Response<T>> post<T>(String path, {dynamic data}) =>
      _dio.post<T>(path, data: data);

  Future<Response<T>> put<T>(String path, {dynamic data}) =>
      _dio.put<T>(path, data: data);

  Future<Response<T>> patch<T>(String path, {dynamic data}) =>
      _dio.patch<T>(path, data: data);

  Future<Response<T>> delete<T>(String path, {dynamic data}) =>
      _dio.delete<T>(path, data: data);
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final flutterSecureStorageProvider = Provider<FlutterSecureStorage>(
  (_) => const FlutterSecureStorage(),
);

final secureStorageProvider = Provider<SecureStorage>(
  (ref) => SecureStorage(ref.watch(flutterSecureStorageProvider)),
);

final apiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(ref.watch(secureStorageProvider)),
);

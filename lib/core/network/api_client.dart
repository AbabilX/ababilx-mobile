import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/api_constants.dart';
import '../storage/secure_storage.dart';

/// Global Dio instance with JWT injection and 401 handling.
/// On 401, clears JWT — the GoRouter auth guard will redirect to /login.
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
          if (error.response?.statusCode == 401) {
            await _storage.clearAll();
            // The authStateProvider will detect null JWT on next read
            // and GoRouter will redirect to /login automatically.
          }
          handler.next(error);
        },
      ),
    );
  }

  late final Dio _dio;
  final SecureStorage _storage;

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
  (_) => const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  ),
);

final secureStorageProvider = Provider<SecureStorage>(
  (ref) => SecureStorage(ref.watch(flutterSecureStorageProvider)),
);

final apiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(ref.watch(secureStorageProvider)),
);

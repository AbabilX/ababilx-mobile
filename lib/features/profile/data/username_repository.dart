import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';

/// Why a handle could not be saved, in the two cases the screen has to say
/// something specific about. Anything else is a network failure and reads as
/// one.
enum UsernameFailure { taken, invalid }

class UsernameException implements Exception {
  const UsernameException(this.reason);
  final UsernameFailure reason;

  String get message => switch (reason) {
    UsernameFailure.taken => 'That username is already taken.',
    UsernameFailure.invalid => 'Use 3 to 32 letters, numbers, . _ or -',
  };

  @override
  String toString() => message;
}

/// Sets or clears the account handle.
///
/// Uniqueness is decided by the server's index, never by asking first: two
/// people typing the same handle at the same moment would both be told it was
/// free. A 409 on save is the answer, and it is the only correct one.
class UsernameRepository {
  const UsernameRepository(this._client);

  final ApiClient _client;

  /// Returns the handle the server stored — lowercased, `@` stripped — so the
  /// phone shows what everyone else will see rather than what was typed.
  Future<String> save(String username) async {
    try {
      final response = await _client.put(
        ApiConstants.meUsername,
        data: {'username': username},
      );
      final data = (response.data as Map<String, dynamic>)['data'];
      if (data is Map<String, dynamic>) {
        return (data['username'] as String? ?? '').trim();
      }
      return username.trim().toLowerCase();
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      if (status == 409) throw const UsernameException(UsernameFailure.taken);
      if (status == 400) throw const UsernameException(UsernameFailure.invalid);
      rethrow;
    }
  }

  Future<String> clear() => save('');
}

final usernameRepositoryProvider = Provider<UsernameRepository>(
  (ref) => UsernameRepository(ref.watch(apiClientProvider)),
);

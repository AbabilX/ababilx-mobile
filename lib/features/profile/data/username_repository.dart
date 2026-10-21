import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../messages/group-link/group_link_api.dart' show retryHint;

/// Why a handle could not be saved, in the two cases the screen has to say
/// something specific about. Anything else is a network failure and reads as
/// one.
enum UsernameFailure { taken, invalid, tooSoon }

class UsernameException implements Exception {
  const UsernameException(this.reason, {this.retry = ''});
  final UsernameFailure reason;

  /// " Try again on 7 Oct." for [UsernameFailure.tooSoon], when the server
  /// said when.
  final String retry;

  String get message => switch (reason) {
    UsernameFailure.taken => 'That username is already taken.',
    UsernameFailure.invalid => 'Use 3 to 32 letters, numbers, . _ or -',
    UsernameFailure.tooSoon =>
      'You can change your username once every 3 days.$retry',
  };

  @override
  String toString() => message;
}

/// Sets or clears the account handle.
///
/// [available] is the typing read. It does not claim the handle: two people
/// can both be told it is free. [save] is what claims it, and a 409 from the
/// unique index is still the answer that wins.
class UsernameRepository {
  const UsernameRepository(this._client);

  final ApiClient _client;

  /// True when no other account holds [username]. The caller's own handle
  /// is free. [username] must already be normalized.
  Future<bool> available(String username) async {
    final response = await _client.get(
      ApiConstants.meUsernameAvailable,
      queryParameters: {'username': username},
    );
    final data = (response.data as Map<String, dynamic>)['data'];
    if (data is Map<String, dynamic>) return data['available'] == true;
    return false;
  }

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
      // Server 0167: a new handle once every three days.
      if (status == 429) {
        throw UsernameException(
          UsernameFailure.tooSoon,
          retry: retryHint(error.response?.data),
        );
      }
      rethrow;
    }
  }

  Future<String> clear() => save('');
}

final usernameRepositoryProvider = Provider<UsernameRepository>(
  (ref) => UsernameRepository(ref.watch(apiClientProvider)),
);

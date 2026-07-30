import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../providers/user_status_provider.dart';

/// Set/clear the caller's own Slack-style custom status.
class UserStatusRepository {
  const UserStatusRepository(this._client);
  final ApiClient _client;

  Future<UserStatus> setStatus({
    required String emoji,
    required String text,
    required int durationHours,
  }) async {
    final res = await _client.put(
      ApiConstants.meStatus,
      data: {'emoji': emoji, 'text': text, 'duration_hours': durationHours},
    );
    final data = (res.data as Map<String, dynamic>)['data'] as Map<String, dynamic>;
    return UserStatus(
      emoji: data['emoji'] as String? ?? '',
      text: data['text'] as String? ?? '',
      expiresAt: DateTime.tryParse(
        data['expires_at'] as String? ?? '',
      )?.toLocal(),
    );
  }

  Future<void> clearStatus() => _client.delete(ApiConstants.meStatus);
}

final userStatusRepositoryProvider = Provider<UserStatusRepository>(
  (ref) => UserStatusRepository(ref.watch(apiClientProvider)),
);

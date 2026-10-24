import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../profile/data/user_status_repository.dart';
import '../../../profile/providers/user_status_provider.dart';

/// "Away" is the ordinary custom status with a fixed face, so every client
/// already shows it beside the name with no server change. The server lets a
/// status live 24 hours at most, so Away clears itself after a day.
const awayEmoji = '🌙';
const awayText = 'Away';

bool isAwayStatus(UserStatus? status) =>
    status != null && status.isActive && status.text == awayText;

/// Flips Away for [userId]. Turning it on replaces any custom status; off
/// clears it. Returns false when the server refused.
Future<bool> toggleAway(WidgetRef ref, String userId) async {
  final repo = ref.read(userStatusRepositoryProvider);
  final statuses = ref.read(userStatusProvider.notifier);
  final away = isAwayStatus(ref.read(userStatusForProvider(userId)));
  try {
    if (away) {
      await repo.clearStatus();
      statuses.setLocal(userId, null);
    } else {
      final saved = await repo.setStatus(
        emoji: awayEmoji,
        text: awayText,
        durationHours: 24,
      );
      statuses.setLocal(userId, saved);
    }
    return true;
  } catch (_) {
    return false;
  }
}

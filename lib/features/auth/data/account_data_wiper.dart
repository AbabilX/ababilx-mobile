import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../calls/data/call_log_cache.dart';
import '../../calls/data/restored_call_log.dart';
import '../../chat-lock/data/chat_lock_index.dart';
import '../../chat-lock/media/ram_media_cache.dart';
import '../../messages/data/local/chat_archive_wiper.dart';
import '../../messages/message_e2ee/message_vault.dart';
import '../../messages/safety_number/safety_number_store.dart';
import '../../notifications/chat/chat_notification_store.dart';
import '../../notifications/chat/chat_notification_dismissals.dart';
import '../../notifications/chat/chat_notification_privacy.dart';
import '../../notifications/providers/fcm_provider.dart';
import '../../profile/data/profile_repository.dart';
import '../../team/data/team_repository.dart';

/// Signal-style account switch: remove everything private to the old account,
/// but never touch files the user exported to AbabilXStorage.
class AccountDataWiper {
  const AccountDataWiper(this._ref);

  final Ref _ref;

  Future<void> clear() async {
    _ref.read(messageVaultProvider).lock();
    await _ref.read(chatArchiveWiperProvider).clear(clearCurrentUser: true);
    await _ref.read(safetyNumberStoreProvider).forgetAll();
    await _ref.read(profileRepositoryProvider).clearCache(strict: true);
    await _ref.read(teamRepositoryProvider).clearCache(strict: true);
    await ChatNotificationStore.clearAll(strict: true);
    await ChatNotificationDismissals.clearAll();
    // Locks and hidden-notification choices belong to the old account's
    // chats; the next account must not inherit them (passwords go with
    // clearAllPrivateData below).
    await ChatLockIndex.clearAll();
    await ChatNotificationPrivacy.clearAll();
    // Names and times of the old account's calls.
    await CallLogCache.clear();
    await RestoredCallLog.clear();
    await RamMediaCache.release();
    await _ref.read(localNotificationsProvider).cancelAll(strict: true);
    await _ref.read(secureStorageProvider).clearAllPrivateData();
  }
}

final accountDataWiperProvider = Provider<AccountDataWiper>(
  AccountDataWiper.new,
);

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../attachments/providers/attachment_providers.dart';
import '../../history-restore/history_restore_flag.dart';
import '../../providers/chat_provider.dart';
import 'chat_key_cache.dart';
import 'chat_message_store.dart';
import 'chat_outbox_cache.dart';
import 'chat_sidebar_cache.dart';

/// Clears only app-private chat state. User-exported MediaStore/Files copies
/// live outside [AttachmentSweeper] and are intentionally unreachable here.
class ChatArchiveWiper {
  const ChatArchiveWiper(this._ref);

  final Ref _ref;

  Future<void> clear({bool clearCurrentUser = false}) async {
    await _ref.read(attachmentQueueProvider).cancelAll();
    await _ref.read(attachmentSweeperProvider).clearAll();
    _ref.invalidate(attachmentAuthorityProvider);
    _ref.invalidate(attachmentQueueProvider);
    await _ref.read(chatOutboxCacheProvider).clearAll();
    await _ref.read(chatMessageStoreProvider).clearAll();
    await _ref.read(chatSidebarCacheProvider).clearAll();
    await _ref.read(chatKeyCacheProvider).clearAll();
    await HistoryRestoreFlag.clearAll();
    _ref
        .read(chatProvider.notifier)
        .resetTeamChatState(clearCurrentUser: clearCurrentUser);
  }
}

final chatArchiveWiperProvider = Provider<ChatArchiveWiper>(
  ChatArchiveWiper.new,
);

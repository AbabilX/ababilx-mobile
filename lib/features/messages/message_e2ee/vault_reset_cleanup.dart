import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../attachments/providers/attachment_providers.dart';
import '../data/local/chat_key_cache.dart';
import '../data/local/chat_message_store.dart';
import '../data/local/chat_outbox_cache.dart';
import '../data/local/chat_sidebar_cache.dart';
import '../history-restore/history_restore_flag.dart';
import '../providers/chat_provider.dart';

// Do not let a server reset leave readable offline history or queued sends.
// Failures remain retryable in the reset dialog, without replacing the key again.
Future<void> clearFreshStartDevice(WidgetRef ref) async {
  await ref.read(attachmentQueueProvider).cancelAll();
  await ref.read(attachmentSweeperProvider).clearAll();
  ref.invalidate(attachmentAuthorityProvider);
  ref.invalidate(attachmentQueueProvider);
  await ref.read(chatOutboxCacheProvider).clearAll();
  await ref.read(chatMessageStoreProvider).clearAll();
  await ref.read(chatSidebarCacheProvider).clearAll();
  // Every stored envelope was sealed to the identity just replaced, so none of
  // them will ever open again.
  await ref.read(chatKeyCacheProvider).clearAll();
  await HistoryRestoreFlag.clearAll();
  ref.read(chatProvider.notifier).resetTeamChatState();
}

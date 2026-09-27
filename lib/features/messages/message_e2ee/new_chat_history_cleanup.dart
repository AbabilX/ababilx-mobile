import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../local-backup/data/local_backup_settings.dart';
import '../archive/archive_provider.dart';
import '../data/local/chat_deletion_sync.dart';
import '../providers/chat_provider.dart';

/// Runs before removing the durable session candidate, so an interrupted
/// cleanup is retried on next launch without clearing newer server messages.
Future<void> cleanNewChatHistory(Ref ref, String userId) async {
  final chat = ref.read(chatProvider.notifier);
  await ref.read(archiveProvider.notifier).cancel();
  await chat.cancelHistoryRestore();
  await syncChatDeletions(ref, userId);
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove('archive_recovery_pending_$userId');
  await prefs.remove('chat_archive_last_backup_ms');
  // History restoration has its own durable flag.
  await chat.completeHistoryReset(userId);
  await chat.clearSidebarCache();
  ref.invalidate(archiveProvider);
  // A fresh start is when a local backup matters most: offer it once.
  await const LocalBackupSettingsStore().armRestoreOffer(userId);
}

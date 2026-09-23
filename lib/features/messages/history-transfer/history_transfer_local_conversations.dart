import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/local/chat_sidebar_cache.dart';
import '../data/models/chat_models.dart';
import '../providers/chat_provider.dart';

/// The conversations this phone knows, from its own cached sidebar — the
/// richest local record of a conversation's name and members. Best effort:
/// messages whose conversation is not here still transfer, under a frame
/// built from the messages themselves (`v2/v2_conversations.dart`).
Future<List<ChatConversation>> localTransferConversations(Ref ref) async {
  try {
    final userId = ref.read(chatProvider).currentUserId;
    if (userId.isEmpty) return const [];
    final sidebar = await ChatSidebarCache(
      ref.read(chatLocalDbProvider),
    ).read(userId);
    if (sidebar == null) return const [];
    return [...sidebar.channels, ...sidebar.dms];
  } catch (_) {
    return const [];
  }
}

/// One sentence for a failed run, from the server's error code when there is
/// one. Kept apart from the approval sheet's messages: this is about a transfer
/// that already started.
String historyTransferFailure(Object error) {
  final text = error.toString();
  if (text.contains('history_transfer_closed')) {
    return 'The transfer was closed on the other device, or it expired.';
  }
  if (text.contains('history_transfer_wrong_device') || text.contains('403')) {
    return 'This phone is no longer the one sending. Scan a new code.';
  }
  if (text.contains('cannot be resumed')) {
    return 'This transfer cannot continue on this phone. Scan a new code.';
  }
  return 'Sending stopped. Keep AbabilX open and try again.';
}

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../messages/data/local/composer_draft_store.dart';
import '../../messages/data/models/chat_models.dart';
import '../../messages/message_e2ee/message_vault.dart';
import '../../messages/providers/chat_provider.dart';
import '../../messages/send-later/scheduled_api.dart';
import '../../messages/send-later/scheduled_message.dart';
import '../../../core/network/api_client.dart';
import 'home_chats.dart';

/// One unsent draft, with the chat it belongs to. The chat is looked up in
/// what Home may show, so a draft in a locked or deleted chat never appears.
class HomeDraft {
  const HomeDraft({required this.draft, required this.conversation});

  final ComposerDraft draft;
  final ChatConversation conversation;
}

/// Drafts are stored text, one per composer, on this phone only. Re-read when
/// Home comes back into view and when a page returns to it — a composer
/// writes as the person types, and listening to every keystroke for a count
/// on a hidden tab would cost more than it shows.
final homeDraftsProvider = FutureProvider.autoDispose<List<HomeDraft>>((
  ref,
) async {
  final conversations = ref.watch(homeConversationsProvider);
  final ownerId = await ref.read(chatProvider.notifier).ensureCurrentUserId();
  final drafts = await ref.read(composerDraftStoreProvider).listAll(ownerId);
  return [
    for (final d in drafts)
      if (homeConversationById(conversations, d.conversationId)
          case final ChatConversation c)
        HomeDraft(draft: d, conversation: c),
  ];
});

/// Every scheduled message of this account's (send later, server 0171),
/// soonest first, opened on this device for the list. Refetched on
/// `chat.scheduled.updated`.
final homeScheduledProvider =
    FutureProvider.autoDispose<List<ScheduledMessage>>((ref) async {
      final rows = await listAllScheduled(ref.watch(apiClientProvider));
      if (rows.isEmpty) return rows;
      final vault = ref.read(messageVaultProvider);
      final userId = await ref
          .read(chatProvider.notifier)
          .ensureCurrentUserId();
      final opened = [
        for (final row in rows)
          row.withOpened(
            await vault.decryptMessage(row.asSealedMessage(userId), userId),
          ),
      ];
      return opened..sort((a, b) => a.sendAt.compareTo(b.sendAt));
    });

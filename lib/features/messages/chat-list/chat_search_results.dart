import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_translations.dart';
import '../chat_list_filters.dart';
import '../data/models/chat_models.dart';
import '../nickname/contact_nickname_provider.dart';
import '../providers/chat_provider.dart';
import '../tiptap_plain_text.dart';
import 'chat_search_matches.dart';
import 'chat_search_section_header.dart';
import 'chat_search_suggestions.dart';
import 'conversation_row.dart';
import '../../chat-lock/providers/chat_locks_provider.dart';
import '../../chat-lock/chat_lock_filter.dart';

/// Signal-Android order: name-matched chats, then message keyword hits.
///
/// Groups-in-common, contacts-without-threads, and media chips are deliberately
/// absent — those sections need data we do not have on this screen.
class ChatSearchResults extends ConsumerWidget {
  const ChatSearchResults({
    super.key,
    required this.query,
    required this.onOpenConversation,
    this.conversationId,
    this.onOpenMessage,
  });

  final String query;

  /// Set when searching inside one chat: other chats are not listed at all.
  final String? conversationId;
  final ValueChanged<String> onOpenConversation;

  /// A hit inside one chat jumps to the message instead of opening the chat.
  final ValueChanged<ChatMessage>? onOpenMessage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chat = ref.watch(chatProvider);
    final nicknames = ref.watch(contactNicknamesProvider);
    String tr(String key) => AppTranslations.translate(context, ref, key);

    final needle = query.trim();
    if (needle.isEmpty) {
      // Inside one chat's search, other chats are not what is being looked
      // for — keep the plain hint there.
      if (conversationId == null) {
        return ChatSearchSuggestions(onOpenConversation: onOpenConversation);
      }
      return Center(child: Text(tr('chat_search_min_chars')));
    }

    // Searching everything never reaches into a locked chat: not its name,
    // not its messages. Searching inside it (conversationId) is its own.
    final locks = ref.watch(chatLocksProvider);
    final chats = conversationId != null
        ? const <ChatConversation>[]
        : matchingSearchConversations(
            unifiedConversations(
              dms: withoutLockedChats(chat.dms, locks),
              channels: withoutLockedChats(chat.channels, locks),
            ),
            needle,
            nicknames: nicknames,
            currentUserId: chat.currentUserId,
          );
    final messages = conversationId == null
        ? chat.searchResults
              .where((message) => !locks.containsKey(message.conversationId))
              .toList()
        : chat.searchResults
              .where((message) => message.conversationId == conversationId)
              .toList();

    // Chats are local, so they paint before the message index returns. A full
    // spinner here used to hide a name match behind "searching messages".
    if (chat.searchLoading && chats.isEmpty && messages.isEmpty) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2.5));
    }
    if (!chat.searchLoading && chats.isEmpty && messages.isEmpty) {
      return Center(child: Text(tr('chat_search_empty')));
    }

    return ListView(
      children: [
        if (chats.isNotEmpty) ...[
          ChatSearchSectionHeader(label: tr('chat_search_chats')),
          for (final conversation in chats)
            ConversationRow(
              conversation: conversation,
              currentUserId: chat.currentUserId,
              onTap: () => onOpenConversation(conversation.id),
            ),
        ],
        if (chat.searchLoading) const LinearProgressIndicator(minHeight: 2),
        if (messages.isNotEmpty) ...[
          ChatSearchSectionHeader(label: tr('chat_search_messages')),
          for (final message in messages)
            _MessageHit(
              message: message,
              showTime: conversationId != null,
              onTap: onOpenMessage != null
                  ? () => onOpenMessage!(message)
                  : () => onOpenConversation(message.conversationId),
            ),
        ],
      ],
    );
  }
}

class _MessageHit extends StatelessWidget {
  const _MessageHit({
    required this.message,
    required this.onTap,
    this.showTime = false,
  });

  final ChatMessage message;
  final VoidCallback onTap;
  final bool showTime;

  @override
  Widget build(BuildContext context) {
    final when = DateTime.tryParse(message.createdAt)?.toLocal();
    return ListTile(
      title: Text(message.userName ?? 'Unknown'),
      trailing: showTime && when != null
          ? Text(
              MaterialLocalizations.of(context).formatShortDate(when),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            )
          : null,
      subtitle: Text(
        tiptapToPreviewText(message.body),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: onTap,
    );
  }
}

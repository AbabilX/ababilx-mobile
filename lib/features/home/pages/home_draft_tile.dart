import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../messages/chat-list/conversation_avatar.dart';
import '../../messages/data/models/chat_models.dart';
import '../../messages/nickname/contact_nickname_provider.dart';
import '../../messages/nickname/nickname_title.dart';
import '../../messages/providers/chat_provider.dart';
import '../data/home_drafts.dart';
import '../quick-views/quick_view_summary.dart';

String _titleOf(WidgetRef ref, ChatConversation c) => ref
    .watch(contactNicknamesProvider)
    .titleFor(c, ref.watch(chatProvider.select((s) => s.currentUserId)));

/// A draft: the chat's picture and name, then the unsent text.
class HomeDraftTile extends ConsumerWidget {
  const HomeDraftTile({super.key, required this.draft, required this.onTap});

  final HomeDraft draft;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final title = _titleOf(ref, draft.conversation);
    final inThread = draft.draft.parentId != null;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ConversationAvatar(
              conversation: draft.conversation,
              title: title,
              size: 40,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    inThread
                        ? '$title · ${homeText(context, ref, 'home_draft_in_thread')}'
                        : title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    draft.draft.text.trim(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: colors.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The small chat-name line above a scheduled message.
class HomeChatLabel extends ConsumerWidget {
  const HomeChatLabel({super.key, required this.conversation});

  final ChatConversation conversation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final title = _titleOf(ref, conversation);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      child: Row(
        children: [
          ConversationAvatar(
            conversation: conversation,
            title: title,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

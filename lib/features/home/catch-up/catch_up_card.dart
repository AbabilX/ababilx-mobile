import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../messages/chat-list/conversation_avatar.dart';
import '../../messages/chat_icon.dart';
import '../../messages/data/models/chat_models.dart';
import '../../messages/nickname/contact_nickname_provider.dart';
import '../../messages/nickname/nickname_title.dart';
import '../../messages/providers/chat_provider.dart';
import '../quick-views/quick_view_summary.dart';
import 'catch_up_bubbles.dart';
import 'catch_up_preview.dart';
import 'catch_up_reply.dart';

/// One conversation on the Catch up deck. The body is the chat's own
/// bubbles for the newest messages — same row the timeline draws.
class CatchUpCard extends ConsumerWidget {
  const CatchUpCard({super.key, required this.conversation});

  final ChatConversation conversation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final me = ref.watch(chatProvider.select((s) => s.currentUserId));
    final title = ref.watch(contactNicknamesProvider).titleFor(conversation, me);
    final messages = ref.watch(catchUpMessagesProvider(conversation.id));
    final n = conversation.unreadCount;
    // Stage is surfaceContainerLowest, bubble fill is surfaceContainerHigh,
    // so the card itself is surface — the same step a chat pane uses.
    return Material(
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: colors.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      child: InkWell(
        onTap: () => context.push(catchUpChatPath(conversation.id)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ConversationAvatar(
                    conversation: conversation,
                    title: title,
                    size: 48,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: colors.onSurface,
                          ),
                        ),
                        if (n > 0)
                          Text(
                            homeText(context, ref, 'home_catch_up_n_new', n),
                            style: text.labelLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: colors.primary,
                            ),
                          ),
                      ],
                    ),
                  ),
                  ChatIcon(
                    HugeIcons.strokeRoundedArrowRight01,
                    color: colors.onSurfaceVariant,
                    size: 22,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: messages.when(
                  data: (rows) => rows.isEmpty
                      ? Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            homeText(context, ref, 'home_catch_up_open_hint'),
                            style: text.bodyMedium?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        )
                      : CatchUpBubbles(
                          messages: rows,
                          currentUserId: me,
                          isGroup: conversation.isGroupConversation,
                        ),
                  loading: () => Align(
                    alignment: Alignment.topLeft,
                    child: Text(
                      '…',
                      style: text.bodyLarge?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                  error: (_, _) => const SizedBox.shrink(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  ChatIcon(
                    HugeIcons.strokeRoundedMessage01,
                    size: 14,
                    color: colors.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      homeText(context, ref, 'home_catch_up_open_hint'),
                      style: text.labelMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

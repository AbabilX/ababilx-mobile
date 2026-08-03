import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../shared/widgets/app_avatar.dart';
import '../chat-forward/forward_sheet.dart';
import '../data/models/chat_models.dart';
import '../providers/chat_provider.dart';
import 'message_actions.dart';
import 'message_body.dart';
import 'quick_react_sheet.dart';
import 'reaction_row.dart';
import 'user_profile_sheet.dart';

String _rootDateLabel(String iso) {
  final dt = DateTime.tryParse(iso)?.toLocal();
  if (dt == null) return '';
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(dt.year, dt.month, dt.day);
  final time = DateFormat('h:mm a').format(dt);
  if (day == today) return 'Today at $time';
  if (day == today.subtract(const Duration(days: 1))) {
    return 'Yesterday at $time';
  }
  return '${DateFormat('d MMM').format(dt)} at $time';
}

/// Root message header for the Thread screen — Slack-style: avatar, name,
/// absolute date/time, body, always-on reaction row, then a "N replies"
/// divider (forward + overflow) separating it from the reply list below.
class ThreadRootCard extends ConsumerWidget {
  const ThreadRootCard({
    super.key,
    required this.message,
    required this.conversationId,
  });

  final ChatMessage message;
  final String conversationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final name = message.userName ?? 'Unknown';
    final n = ref.read(chatProvider.notifier);
    final replyCount = message.threadCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () => showUserProfileSheet(
                  context: context,
                  ref: ref,
                  userId: message.userId,
                  userName: name,
                  userAvatarUrl: message.userAvatarUrl,
                ),
                child: AppAvatar(
                  size: 36,
                  url: message.userAvatarUrl,
                  name: name,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _rootDateLabel(message.createdAt),
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    MessageBody(message: message),
                    ReactionRow(
                      reactions: message.reactions,
                      onToggle: (emoji) => n.toggleReaction(message.id, emoji),
                      onAdd: () async {
                        final emoji = await showQuickReactSheet(context);
                        if (emoji != null) {
                          await n.toggleReaction(message.id, emoji);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (replyCount > 0)
          _ReplyDivider(
            count: replyCount,
            onForward: () => showForwardSheet(context, ref, message),
            onMore: () => showMessageActions(
              context,
              ref,
              message,
              conversationId: conversationId,
            ),
          ),
      ],
    );
  }
}

class _ReplyDivider extends StatelessWidget {
  const _ReplyDivider({
    required this.count,
    required this.onForward,
    required this.onMore,
  });

  final int count;
  final VoidCallback onForward;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final line = Divider(
      height: 1,
      color: colors.outlineVariant.withValues(alpha: 0.4),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 0),
      child: Column(
        children: [
          line,
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '$count ${count == 1 ? 'reply' : 'replies'}',
                    style: TextStyle(
                      fontSize: 13,
                      color: colors.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.forward_rounded, size: 20),
                  visualDensity: VisualDensity.compact,
                  onPressed: onForward,
                ),
                IconButton(
                  icon: const Icon(Icons.more_vert, size: 20),
                  visualDensity: VisualDensity.compact,
                  onPressed: onMore,
                ),
              ],
            ),
          ),
          line,
        ],
      ),
    );
  }
}

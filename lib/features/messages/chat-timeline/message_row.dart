import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/app_avatar.dart';
import '../chat_utils.dart';
import '../data/models/chat_models.dart';
import '../providers/chat_provider.dart';
import 'message_actions.dart';
import 'message_body.dart';
import 'quick_react_sheet.dart';
import 'reaction_row.dart';
import 'thread_sheet.dart';
import 'thread_summary.dart';

import 'user_profile_sheet.dart';

class MessageRow extends ConsumerStatefulWidget {
  const MessageRow({
    super.key,
    required this.message,
    required this.conversationId,
    this.threadRootId,
    this.onOpenThread,
  });

  final ChatMessage message;
  final String conversationId;
  final String? threadRootId;
  final VoidCallback? onOpenThread;

  @override
  ConsumerState<MessageRow> createState() => _MessageRowState();
}

class _MessageRowState extends ConsumerState<MessageRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _onRetry(BuildContext ctx) {
    final n = ref.read(chatProvider.notifier);
    n.retrySend(widget.message);
    ScaffoldMessenger.of(ctx).showSnackBar(
      const SnackBar(
        content: Text('Resending message…'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final name = widget.message.userName ?? 'Unknown';
    final n = ref.read(chatProvider.notifier);
    final chat = ref.watch(chatProvider);

    final conversation = chat.conversationById(widget.conversationId);
    final isDm = conversation?.isDm ?? true;
    final isOwnMessage = widget.message.userId == chat.currentUserId;
    final isSending =
        isOwnMessage && widget.message.sendStatus == MessageSendStatus.sending;
    final isFailed =
        isOwnMessage && widget.message.sendStatus == MessageSendStatus.failed;

    Widget buildStatusIcon() {
      if (isSending) {
        return FadeTransition(
          opacity: _pulseAnim,
          child: Icon(
            Icons.schedule_rounded,
            size: 13,
            color: colors.onSurfaceVariant,
          ),
        );
      }
      if (isFailed) {
        return Icon(
          Icons.error_outline_rounded,
          size: 14,
          color: colors.error,
        );
      }
      return const SizedBox.shrink();
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPress: () => showMessageActions(
        context,
        ref,
        widget.message,
        conversationId: widget.conversationId,
        threadRootId: widget.threadRootId,
      ),
      onTap: isFailed ? () => _onRetry(context) : null,
      onDoubleTap: widget.threadRootId == null && !isFailed
          ? () {
              if (isDm) {
                n.setReplyToMessage(widget.message);
              } else {
                openThreadSheet(context, widget.conversationId, widget.message);
              }
            }
          : null,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: isSending ? 0.65 : 1.0,
        child: Container(
          // Subtle red tint on the row background for failed messages.
          decoration: isFailed
              ? BoxDecoration(
                  color: colors.errorContainer.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                )
              : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () {
                    showUserProfileSheet(
                      context: context,
                      ref: ref,
                      userId: widget.message.userId,
                      userName: name,
                      userAvatarUrl: widget.message.userAvatarUrl,
                    );
                  },
                  child: AppAvatar(
                    size: 36,
                    url: widget.message.userAvatarUrl,
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
                            child: GestureDetector(
                              onTap: () {
                                showUserProfileSheet(
                                  context: context,
                                  ref: ref,
                                  userId: widget.message.userId,
                                  userName: name,
                                  userAvatarUrl: widget.message.userAvatarUrl,
                                );
                              },
                              child: Text(
                                name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          buildStatusIcon(),
                          const SizedBox(width: 4),
                          if (!isSending)
                            Text(
                              isFailed
                                  ? 'Tap to retry'
                                  : formatChatTime(widget.message.createdAt),
                              style: TextStyle(
                                fontSize: 12,
                                color: isFailed
                                    ? colors.error
                                    : colors.onSurfaceVariant,
                                fontWeight: isFailed
                                    ? FontWeight.w500
                                    : FontWeight.normal,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      MessageBody(message: widget.message),
                      if (!widget.message.isDeleted &&
                          widget.message.reactions.isNotEmpty)
                        ReactionRow(
                          reactions: widget.message.reactions,
                          onToggle: (emoji) =>
                              n.toggleReaction(widget.message.id, emoji),
                          onAdd: () async {
                            final emoji = await showQuickReactSheet(context);
                            if (emoji != null) {
                              await n.toggleReaction(widget.message.id, emoji);
                            }
                          },
                        ),
                      if (widget.onOpenThread != null)
                        ThreadSummary(
                          root: widget.message,
                          replies: ref
                                  .watch(chatProvider)
                                  .threadRepliesByRoot[widget.message.id] ??
                              const [],
                          count: widget.message.threadCount,
                          onTap: widget.onOpenThread!,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/chat_models.dart';
import '../chat_utils.dart';
import '../chat-date-divider/index.dart';
import '../providers/chat_provider.dart';
import '../chat-forward/forward-dialog.dart';
import 'message-composer.dart';

class ChatTimeline extends ConsumerStatefulWidget {
  const ChatTimeline({
    super.key,
    required this.conversationId,
    this.threadRootId,
  });

  final String conversationId;
  final String? threadRootId;

  @override
  ConsumerState<ChatTimeline> createState() => _ChatTimelineState();
}

class _ChatTimelineState extends ConsumerState<ChatTimeline> {
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(covariant ChatTimeline oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.conversationId != widget.conversationId ||
        oldWidget.threadRootId != widget.threadRootId) {
      _load();
    }
  }

  void _load() {
    ref.read(chatProvider.notifier).loadFeed(
          widget.conversationId,
          threadRootId: widget.threadRootId,
        );
    if (widget.threadRootId == null) {
      ref.read(chatProvider.notifier).markConversationRead(widget.conversationId);
    }
  }

  void _onScroll() {
    if (!_scrollCtrl.hasClients) return;
    if (_scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 120) {
      ref.read(chatProvider.notifier).loadMoreFeed(
            widget.conversationId,
            threadRootId: widget.threadRootId,
          );
    }
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chat = ref.watch(chatProvider);
    final feed = chat.feedFor(widget.conversationId, threadRootId: widget.threadRootId);
    final currentUserId = chat.currentUserId;

    return Column(
      children: [
        Expanded(
          child: feed.loading && feed.messages.isEmpty
              ? const Center(child: CircularProgressIndicator(strokeWidth: 2.5))
              : ListView.builder(
                  controller: _scrollCtrl,
                  reverse: true,
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                  itemCount: feed.messages.length + (feed.loadingMore ? 1 : 0),
                  itemBuilder: (_, i) {
                    if (feed.loadingMore && i == feed.messages.length) {
                      return const Padding(
                        padding: EdgeInsets.all(12),
                        child: Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      );
                    }
                    final idx = feed.messages.length - 1 - i;
                    final msg = feed.messages[idx];
                    final prev = idx > 0 ? feed.messages[idx - 1] : null;
                    final showDate = prev == null || !isSameDay(prev.createdAt, msg.createdAt);
                    return Column(
                      children: [
                        if (showDate)
                          ChatDateDivider(label: formatDateDivider(msg.createdAt)),
                        _MessageBubble(
                          message: msg,
                          isMine: msg.userId == currentUserId,
                          onLongPress: () => _showActions(context, msg),
                          onOpenThread: widget.threadRootId == null && msg.threadCount > 0
                              ? () => _openThread(msg)
                              : null,
                        ),
                      ],
                    );
                  },
                ),
        ),
        MessageComposer(
          conversationId: widget.conversationId,
          parentId: widget.threadRootId,
        ),
      ],
    );
  }

  void _openThread(ChatMessage msg) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, __) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Thread',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ChatTimeline(
                conversationId: widget.conversationId,
                threadRootId: msg.id,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showActions(BuildContext context, ChatMessage msg) async {
    if (msg.isDeleted) return;
    final isMine = msg.userId == ref.read(chatProvider).currentUserId;
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.add_reaction_outlined),
              title: const Text('React 👍'),
              onTap: () => Navigator.pop(ctx, 'react'),
            ),
            ListTile(
              leading: const Icon(Icons.forward_outlined),
              title: const Text('Forward'),
              onTap: () => Navigator.pop(ctx, 'forward'),
            ),
            if (widget.threadRootId == null)
              ListTile(
                leading: const Icon(Icons.forum_outlined),
                title: const Text('Reply in thread'),
                onTap: () => Navigator.pop(ctx, 'thread'),
              ),
            if (isMine)
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Edit'),
                onTap: () => Navigator.pop(ctx, 'edit'),
              ),
            if (isMine)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('Delete', style: TextStyle(color: Colors.red)),
                onTap: () => Navigator.pop(ctx, 'delete'),
              ),
          ],
        ),
      ),
    );

    if (!mounted) return;
    switch (action) {
      case 'react':
        await ref.read(chatProvider.notifier).toggleReaction(msg.id, '👍');
      case 'forward':
        if (context.mounted) {
          await showForwardDialog(context, ref, msg);
        }
      case 'thread':
        _openThread(msg);
      case 'edit':
        final edited = await _editMessage(context, msg.body);
        if (edited != null) {
          await ref.read(chatProvider.notifier).editMessage(msg.id, edited);
        }
      case 'delete':
        await ref.read(chatProvider.notifier).deleteMessage(msg.id);
    }
  }

  Future<String?> _editMessage(BuildContext context, String initial) async {
    final ctrl = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit message'),
        content: TextField(controller: ctrl, maxLines: 4),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.isMine,
    required this.onLongPress,
    this.onOpenThread,
  });

  final ChatMessage message;
  final bool isMine;
  final VoidCallback onLongPress;
  final VoidCallback? onOpenThread;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final bg = isMine ? colors.primaryContainer : colors.surfaceContainerHigh;
    final fg = isMine ? colors.onPrimaryContainer : colors.onSurface;

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: onLongPress,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.78,
          ),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(isMine ? 16 : 4),
              bottomRight: Radius.circular(isMine ? 4 : 16),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isMine && message.userName != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    message.userName!,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: colors.primary,
                    ),
                  ),
                ),
              if (message.isDeleted)
                Text('Message deleted', style: TextStyle(color: fg.withValues(alpha: 0.6), fontStyle: FontStyle.italic))
              else ...[
                if (message.forwardedFromName != null)
                  Text(
                    'Forwarded from ${message.forwardedFromName}',
                    style: TextStyle(fontSize: 11, color: fg.withValues(alpha: 0.7)),
                  ),
                Text(message.body, style: TextStyle(color: fg)),
                ...message.attachments.map(
                  (a) => _AttachmentTile(attachment: a),
                ),
              ],
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    formatChatTime(message.createdAt),
                    style: TextStyle(fontSize: 10, color: fg.withValues(alpha: 0.65)),
                  ),
                  if (message.editedAt != null) ...[
                    const SizedBox(width: 4),
                    Text('edited', style: TextStyle(fontSize: 10, color: fg.withValues(alpha: 0.65))),
                  ],
                ],
              ),
              if (message.reactions.isNotEmpty)
                Wrap(
                  spacing: 4,
                  children: message.reactions
                      .map((r) => Chip(
                            visualDensity: VisualDensity.compact,
                            label: Text('${r.emoji} ${r.count}'),
                          ))
                      .toList(),
                ),
              if (onOpenThread != null)
                TextButton(
                  onPressed: onOpenThread,
                  child: Text('${message.threadCount} replies'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AttachmentTile extends StatelessWidget {
  const _AttachmentTile({required this.attachment});
  final ChatMessageAttachment attachment;

  @override
  Widget build(BuildContext context) {
    if (attachment.contentType.startsWith('image/')) {
      return Padding(
        padding: const EdgeInsets.only(top: 6),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: CachedNetworkImage(
            imageUrl: attachment.fileUrl,
            height: 160,
            fit: BoxFit.cover,
          ),
        ),
      );
    }
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.insert_drive_file_outlined, size: 20),
      title: Text(attachment.fileName, maxLines: 1, overflow: TextOverflow.ellipsis),
    );
  }
}

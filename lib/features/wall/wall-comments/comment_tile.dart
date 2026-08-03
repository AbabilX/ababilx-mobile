import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../shared/widgets/app_avatar.dart';
import '../../../shared/widgets/link_preview.dart';
import '../../messages/chat_icon.dart';
import '../data/models/wall_models.dart';
import '../providers/wall_provider.dart';
import '../providers/wall_ui_provider.dart';
import '../wall_copy_actions.dart';
import '../wall_delete_confirm.dart';
import '../wall-post/attachment_grid.dart';
import '../wall_utils.dart';

class WallCommentTile extends ConsumerWidget {
  const WallCommentTile({
    super.key,
    required this.comment,
    required this.postId,
    this.isReply = false,
    this.replyToName,
    this.onReply,
  });

  final WallComment comment;
  final String postId;
  final bool isReply;
  final String? replyToName;
  final VoidCallback? onReply;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final me = ref.watch(wallProvider).currentUserId;
    final plain = wallBodyPlain(comment.body);

    // Long-press → action sheet (copy/reply/delete), double-tap → quick
    // copy — same entry points as DM message rows.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPress: () => _showActions(context, ref, plain),
      onDoubleTap: plain.trim().isEmpty
          ? null
          : () => copyWallText(context, plain),
      child: Padding(
        padding: const EdgeInsets.only(top: 6, bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppAvatar(
              name: comment.userName ?? '?',
              url: comment.userAvatarUrl,
              size: isReply ? 24 : 28,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isReply && replyToName != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        'Replying to $replyToName',
                        style: TextStyle(
                          fontSize: 11,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  Text(
                    comment.userName ?? 'Member',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  if (plain.trim().isNotEmpty)
                    Text(plain, style: TextStyle(color: scheme.onSurface)),
                  if (plain.trim().isNotEmpty) MessageLinkPreviews(text: plain),
                  if (comment.attachments.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    WallAttachmentGrid(attachments: comment.attachments),
                  ],
                  Row(
                    children: [
                      Text(
                        wallRelativeTime(comment.createdAt),
                        style: TextStyle(
                          fontSize: 11,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      if (comment.userId == me)
                        TextButton(
                          onPressed: () => _confirmDelete(context, ref),
                          child: const Text('Delete'),
                        ),
                      if (onReply != null)
                        TextButton(
                          onPressed: onReply,
                          child: const Text('Reply'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showActions(
    BuildContext context,
    WidgetRef ref,
    String plain,
  ) async {
    final ui = ref.read(wallUiProvider.notifier);
    ui.setPostActionsSheetOpen(true);
    final String? action;
    try {
      action = await showModalBottomSheet<String>(
        context: context,
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (plain.trim().isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.copy_rounded, size: 22),
                  title: const Text('Copy'),
                  onTap: () => Navigator.pop(ctx, 'copy'),
                ),
              if (onReply != null)
                ListTile(
                  leading: const Icon(Icons.reply, size: 22),
                  title: const Text('Reply'),
                  onTap: () => Navigator.pop(ctx, 'reply'),
                ),
              if (comment.userId == ref.read(wallProvider).currentUserId)
                ListTile(
                  leading: ChatIcon(
                    HugeIcons.strokeRoundedDelete02,
                    color: Colors.red.shade300,
                  ),
                  title: const Text(
                    'Delete',
                    style: TextStyle(color: Colors.red),
                  ),
                  onTap: () => Navigator.pop(ctx, 'delete'),
                ),
            ],
          ),
        ),
      );
    } finally {
      ui.setPostActionsSheetOpen(false);
    }
    if (!context.mounted || action == null) return;
    switch (action) {
      case 'copy':
        await copyWallText(context, plain);
      case 'reply':
        onReply?.call();
      case 'delete':
        await _confirmDelete(context, ref);
    }
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final ok = await confirmWallDelete(
      context,
      title: 'Delete comment?',
      message: 'This comment will be removed. This cannot be undone.',
    );
    if (!ok || !context.mounted) return;
    await ref.read(wallProvider.notifier).deleteComment(postId, comment.id);
  }
}

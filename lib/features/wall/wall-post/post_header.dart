import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../shared/widgets/app_avatar.dart';
import '../../messages/chat_icon.dart';
import '../data/models/wall_models.dart';
import '../providers/wall_provider.dart';
import '../providers/wall_ui_provider.dart';
import '../wall_delete_confirm.dart';
import '../wall_utils.dart';

class WallPostHeader extends ConsumerWidget {
  const WallPostHeader({super.key, required this.post, required this.isOwner});

  final WallPost post;
  final bool isOwner;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        AppAvatar(
          name: post.userName ?? '?',
          url: post.userAvatarUrl,
          size: 36,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                post.userName ?? 'Member',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                ),
              ),
              Row(
                children: [
                  Text(
                    wallRelativeTime(post.createdAt),
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  if (post.category.isNotEmpty) ...[
                    Text(
                      ' · ',
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                    Flexible(
                      child: Text(
                        '#${post.category}',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        if (isOwner)
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: () => _menu(context, ref),
            icon: const ChatIcon(HugeIcons.strokeRoundedMoreVertical),
          ),
      ],
    );
  }

  Future<void> _menu(BuildContext context, WidgetRef ref) async {
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
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Delete post'),
                onTap: () => Navigator.pop(ctx, 'delete'),
              ),
            ],
          ),
        ),
      );
    } finally {
      ui.setPostActionsSheetOpen(false);
    }
    if (action != 'delete' || !context.mounted) return;
    final ok = await confirmWallDelete(
      context,
      title: 'Delete post?',
      message:
          'This post and its comments will be removed. This cannot be undone.',
    );
    if (ok && context.mounted) {
      await ref.read(wallProvider.notifier).deletePost(post.id);
    }
  }
}

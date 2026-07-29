import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../messages/chat_icon.dart';
import '../../messages/chat-timeline/quick_react_sheet.dart';
import '../data/models/wall_models.dart';
import '../providers/wall_provider.dart';
import '../providers/wall_ui_provider.dart';
import '../wall-forward/forward_sheet.dart';

class WallPostActions extends ConsumerWidget {
  const WallPostActions({
    super.key,
    required this.post,
    this.onComment,
    this.showComment = true,
  });

  final WallPost post;
  /// When set (e.g. already on post detail), Comment won't push another page.
  final VoidCallback? onComment;
  /// Hide on post detail — composer is already fixed at the bottom.
  final bool showComment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final n = ref.read(wallProvider.notifier);

    return Row(
      children: [
        _Action(
          icon: HugeIcons.strokeRoundedSmile,
          label: 'React',
          onTap: () async {
            final ui = ref.read(wallUiProvider.notifier);
            ui.setReactionSheetOpen(true);
            try {
              final emoji = await showQuickReactSheet(context);
              if (emoji != null) await n.react(post.id, emoji);
            } finally {
              ui.setReactionSheetOpen(false);
            }
          },
        ),
        if (showComment)
          _Action(
            icon: HugeIcons.strokeRoundedComment01,
            label: '${post.commentCount}',
            onTap: onComment ??
                () {
                  final router = GoRouter.maybeOf(context);
                  if (router == null) return;
                  final loc = GoRouterState.of(context).matchedLocation;
                  if (loc == '/wall/post/${post.id}') return;
                  context.push('/wall/post/${post.id}');
                },
          ),
        _Action(
          icon: post.savedByMe
              ? HugeIcons.strokeRoundedBookmark02
              : HugeIcons.strokeRoundedBookmark01,
          label: post.savedByMe ? 'Saved' : 'Save',
          color: post.savedByMe ? scheme.primary : null,
          onTap: () => n.toggleSave(post.id),
        ),
        _Action(
          icon: HugeIcons.strokeRoundedShare01,
          label: 'Share',
          onTap: () => showWallForwardSheet(context, ref, post.id),
        ),
      ],
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  final List<List<dynamic>> icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final c = color ?? scheme.onSurfaceVariant;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ChatIcon(icon, size: 18, color: c),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: c,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

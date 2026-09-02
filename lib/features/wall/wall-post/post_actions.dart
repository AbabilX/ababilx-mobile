import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../messages/chat_icon.dart';
import '../data/models/wall_models.dart';
import '../providers/wall_provider.dart';
import '../providers/wall_ui_provider.dart';
import '../wall-forward/forward_sheet.dart';
import 'wall_react_sheet.dart';

/// Web default for an unreacted post ([wall-post-card.tsx]).
const kWallDefaultReaction = '👏';

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
    final myReaction = post.reactions.where((r) => r.reactedByMe).firstOrNull;
    final hasReacted = myReaction != null;

    Future<void> toggleDefault() async {
      if (hasReacted) {
        await n.react(post.id, myReaction.emoji);
      } else {
        await n.react(post.id, kWallDefaultReaction);
      }
    }

    Future<void> openPicker() async {
      final ui = ref.read(wallUiProvider.notifier);
      ui.setReactionSheetOpen(true);
      try {
        final emoji = await showWallReactSheet(context);
        if (emoji != null) await n.react(post.id, emoji);
      } finally {
        ui.setReactionSheetOpen(false);
      }
    }

    return Row(
      children: [
        _Action(
          leading: Text(
            hasReacted ? myReaction.emoji : kWallDefaultReaction,
            style: TextStyle(
              fontSize: 16,
              color: hasReacted ? null : scheme.onSurfaceVariant,
            ),
          ),
          label: hasReacted
              ? _reactionLabel(myReaction.emoji, active: true)
              : 'Clap',
          color: hasReacted ? scheme.primary : null,
          onTap: toggleDefault,
          onLongPress: openPicker,
        ),
        if (showComment)
          _Action(
            icon: HugeIcons.strokeRoundedComment01,
            label: '${post.commentCount}',
            onTap:
                onComment ??
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

String _reactionLabel(String emoji, {required bool active}) {
  switch (emoji) {
    case '👏':
      return active ? 'Clapped' : 'Clap';
    case '👍':
      return active ? 'Liked' : 'Like';
    case '❤️':
      return active ? 'Loved' : 'Love';
    case '🎉':
      return active ? 'Celebrated' : 'Celebrate';
    case '💡':
      return active ? 'Insightful' : 'Insight';
    case '🚀':
      return active ? 'Launched' : 'Launch';
    default:
      return active ? 'Reacted' : 'Clap';
  }
}

class _Action extends StatelessWidget {
  const _Action({
    required this.label,
    required this.onTap,
    this.icon,
    this.leading,
    this.onLongPress,
    this.color,
  }) : assert(icon != null || leading != null);

  final List<List<dynamic>>? icon;
  final Widget? leading;
  final String label;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final c = color ?? scheme.onSurfaceVariant;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (leading != null)
                leading!
              else
                ChatIcon(icon!, size: 18, color: c),
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

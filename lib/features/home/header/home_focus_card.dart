import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/constants/app_colors.dart';
import '../../messages/chat-list/conversation_avatar.dart';
import '../../messages/chat_icon.dart';
import '../../messages/data/models/chat_models.dart';
import '../../messages/nickname/contact_nickname_provider.dart';
import '../../messages/nickname/nickname_title.dart';
import '../../messages/providers/chat_provider.dart';
import '../data/home_chats.dart';
import '../quick-views/quick_view_summary.dart';
import 'home_caught_up_art.dart';

/// The one thing Home says first: what is waiting. Clock art (morning ·
/// afternoon · evening · night) always fills the card; only the foreground
/// swaps — unread faces + "N new" + Catch up, or the quiet all-caught-up
/// check. No theme art.
class HomeFocusCard extends ConsumerWidget {
  const HomeFocusCard({super.key});

  static const _radius = 24.0;
  static const _height = 108.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(homeUnreadProvider);
    final clear = unread.isEmpty;
    final art = homeCaughtUpArt(DateTime.now());
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Material(
        color: art.underfill,
        borderRadius: BorderRadius.circular(_radius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: clear ? null : () => context.push('/home/catch-up'),
          child: SizedBox(
            height: _height,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Positioned.fill(
                  child: Image.asset(
                    art.asset,
                    fit: BoxFit.cover,
                    alignment: Alignment.topRight,
                    filterQuality: FilterQuality.high,
                    gaplessPlayback: true,
                  ),
                ),
                clear
                    ? _CaughtUpCopy(ink: art.ink)
                    : _UnreadCopy(unread: unread, ink: art.ink, ring: art.underfill),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Calm state: check + copy on the left. Ink is fixed per clock slot
/// (black on bright art, white on evening/night).
class _CaughtUpCopy extends ConsumerWidget {
  const _CaughtUpCopy({required this.ink});

  final Color ink;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.green,
            child: const ChatIcon(
              HugeIcons.strokeRoundedTick02,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  homeText(context, ref, 'home_focus_clear'),
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: ink,
                  ),
                ),
                Text(
                  homeText(context, ref, 'home_focus_clear_sub'),
                  style: TextStyle(
                    fontSize: 13,
                    color: ink.withValues(alpha: 0.75),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UnreadCopy extends ConsumerWidget {
  const _UnreadCopy({
    required this.unread,
    required this.ink,
    required this.ring,
  });

  final List<ChatConversation> unread;
  final Color ink;
  final Color ring;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
      child: Row(
        children: [
          _Faces(
            ids: [for (final c in unread.take(3)) c.id],
            ring: ring,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  homeText(
                    context,
                    ref,
                    'home_focus_new',
                    unreadMessageCount(unread),
                  ),
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: ink,
                  ),
                ),
                Text(
                  homeText(context, ref, 'home_focus_in_chats', unread.length),
                  style: TextStyle(
                    fontSize: 13,
                    color: ink.withValues(alpha: 0.75),
                  ),
                ),
              ],
            ),
          ),
          FilledButton(
            onPressed: () => context.push('/home/catch-up'),
            style: FilledButton.styleFrom(
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            child: Text(homeText(context, ref, 'home_catch_up')),
          ),
        ],
      ),
    );
  }
}

/// Up to three unread chats' faces, overlapping, each ringed in the art's
/// underfill so the overlap reads as a stack over the photo.
class _Faces extends ConsumerWidget {
  const _Faces({required this.ids, required this.ring});

  final List<String> ids;
  final Color ring;

  static const _size = 40.0;
  static const _step = 24.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chats = ref.watch(homeUnreadProvider);
    final names = ref.watch(contactNicknamesProvider);
    final me = ref.watch(chatProvider.select((s) => s.currentUserId));
    final shown = [for (final id in ids) ?homeConversationById(chats, id)];
    return SizedBox(
      width: _size + _step * (shown.length - 1).clamp(0, 2),
      height: _size,
      child: Stack(
        children: [
          for (var i = shown.length - 1; i >= 0; i--)
            Positioned(
              left: _step * i,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: ring, width: 2),
                ),
                child: ConversationAvatar(
                  conversation: shown[i],
                  title: names.titleFor(shown[i], me),
                  size: _size - 4,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

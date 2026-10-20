import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../messages/chat-list/conversation_avatar.dart';
import '../../messages/chat_icon.dart';
import '../../messages/nickname/contact_nickname_provider.dart';
import '../../messages/nickname/nickname_title.dart';
import '../../messages/providers/chat_provider.dart';
import '../data/home_chats.dart';
import '../quick-views/quick_view_summary.dart';

/// The one thing Home says first: what is waiting. Unread chats show as a
/// stack of faces beside "12 new messages · in 3 chats" and a Catch up
/// capsule; nothing waiting turns it into a quiet "all caught up".
class HomeFocusCard extends ConsumerWidget {
  const HomeFocusCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final unread = ref.watch(homeUnreadProvider);
    final clear = unread.isEmpty;
    final fill = clear ? colors.surfaceContainerHigh : colors.primaryContainer;
    final ink = clear ? colors.onSurface : colors.onPrimaryContainer;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Material(
        color: fill,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: clear ? null : () => context.push('/home/unread'),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
            child: Row(
              children: [
                clear
                    ? CircleAvatar(
                        radius: 22,
                        backgroundColor: colors.surfaceContainerHighest,
                        child: ChatIcon(
                          HugeIcons.strokeRoundedCheckmarkCircle02,
                          color: colors.primary,
                        ),
                      )
                    : _Faces(ids: [for (final c in unread.take(3)) c.id]),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        clear
                            ? homeText(context, ref, 'home_focus_clear')
                            : homeText(
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
                        clear
                            ? homeText(context, ref, 'home_focus_clear_sub')
                            : homeText(
                                context,
                                ref,
                                'home_focus_in_chats',
                                unread.length,
                              ),
                        style: TextStyle(
                          fontSize: 13,
                          color: ink.withValues(alpha: 0.75),
                        ),
                      ),
                    ],
                  ),
                ),
                if (!clear)
                  FilledButton(
                    onPressed: () => context.push('/home/unread'),
                    style: FilledButton.styleFrom(
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    child: Text(homeText(context, ref, 'home_catch_up')),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Up to three unread chats' faces, overlapping, each ringed in the card's
/// own fill so the overlap reads as a stack.
class _Faces extends ConsumerWidget {
  const _Faces({required this.ids});

  final List<String> ids;

  static const _size = 40.0;
  static const _step = 24.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ring = Theme.of(context).colorScheme.primaryContainer;
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

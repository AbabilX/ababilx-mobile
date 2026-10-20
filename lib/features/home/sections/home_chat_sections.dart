import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../messages/chat-list/conversation_avatar.dart';
import '../../messages/chat-list/conversation_row.dart';
import '../../messages/data/models/chat_models.dart';
import '../../messages/nickname/contact_nickname_provider.dart';
import '../../messages/nickname/nickname_title.dart';
import '../../messages/providers/chat_provider.dart';
import '../data/home_chats.dart';
import '../quick-views/quick_view_summary.dart';
import 'home_section.dart';

/// Chats pinned from the chat list's long press, as faces for one-tap
/// access. Pins are the server's (four at most), so they match Messages.
class HomePinnedSection extends ConsumerWidget {
  const HomePinnedSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pinned = ref.watch(homePinnedProvider);
    if (pinned.isEmpty) return const SizedBox.shrink();
    final names = ref.watch(contactNicknamesProvider);
    final me = ref.watch(chatProvider.select((s) => s.currentUserId));
    return HomeSection(
      title: homeText(context, ref, 'home_pinned'),
      child: HomeStrip(
        height: HomeFaceTile.heightFor(context, face: 60),
        gap: 6,
        children: [
          for (final c in pinned)
            HomeFaceTile(
              key: ValueKey(c.id),
              label: names.titleFor(c, me),
              bold: c.unreadCount > 0,
              avatar: _Badged(
                conversation: c,
                child: ConversationAvatar(
                  conversation: c,
                  title: names.titleFor(c, me),
                  size: 60,
                ),
              ),
              onTap: () => context.push('/messages/${c.id}'),
            ),
        ],
      ),
    );
  }
}

/// The newest chats that are not pinned, drawn with the chat list's own
/// rows (picture, name, preview, time). "See all" goes to Messages.
class HomeRecentChatsSection extends ConsumerWidget {
  const HomeRecentChatsSection({super.key});

  static const _shown = 6;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recents = ref.watch(homeRecentsProvider).take(_shown).toList();
    if (recents.isEmpty) return const SizedBox.shrink();
    final me = ref.watch(chatProvider.select((s) => s.currentUserId));
    return HomeSection(
      title: homeText(context, ref, 'home_recent_chats'),
      actionLabel: homeText(context, ref, 'home_see_all'),
      onAction: () => context.go('/messages'),
      child: Column(
        children: [
          for (final c in recents)
            ConversationRow(
              key: ValueKey(c.id),
              conversation: c,
              currentUserId: me,
              onTap: () => context.push('/messages/${c.id}'),
            ),
        ],
      ),
    );
  }
}

/// The chat's unread count over the top-right of its face.
class _Badged extends StatelessWidget {
  const _Badged({required this.conversation, required this.child});

  final ChatConversation conversation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final n = conversation.unreadCount;
    if (n <= 0) return child;
    final colors = Theme.of(context).colorScheme;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          right: -2,
          top: -2,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: colors.primary,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: colors.surface, width: 2),
            ),
            child: Text(
              n > 99 ? '99+' : '$n',
              style: TextStyle(
                color: colors.onPrimary,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

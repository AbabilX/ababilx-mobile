import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/app_avatar.dart';
import '../../profile/providers/profile_provider.dart';
import '../nickname/contact_nickname_provider.dart';
import '../providers/chat_provider.dart';
import 'reaction_details.dart';
import 'user_profile_sheet.dart';

/// Who reacted, one tab per emoji. Works for a DM and a group — the roster
/// is whatever the message already carries.
Future<void> showReactionDetailsSheet({
  required BuildContext context,
  required String messageId,
  String? initialEmoji,
}) {
  if (messageId.isEmpty) return Future.value();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) =>
        ReactionDetailsSheet(messageId: messageId, initialEmoji: initialEmoji),
  );
}

class ReactionDetailsSheet extends ConsumerWidget {
  const ReactionDetailsSheet({
    super.key,
    required this.messageId,
    this.initialEmoji,
  });

  final String messageId;
  final String? initialEmoji;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chat = ref.watch(chatProvider);
    final message = findChatMessage(chat, messageId);
    final groups = message?.reactions ?? const [];
    final tabs = buildReactionDetailTabs(groups);

    if (tabs.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) Navigator.of(context).pop();
      });
      return const SizedBox(height: 1);
    }

    final initial = reactionDetailsInitialTab(
      tabs: tabs,
      initialEmoji: initialEmoji,
    );

    return DefaultTabController(
      key: ValueKey('${tabs.length}:${initialEmoji ?? ''}'),
      length: tabs.length,
      initialIndex: initial.clamp(0, tabs.length - 1),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.52,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(
                  'Reactions',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TabBar(
                isScrollable: tabs.length > 3,
                tabAlignment: tabs.length > 3
                    ? TabAlignment.start
                    : TabAlignment.fill,
                labelColor: Theme.of(context).colorScheme.onSurface,
                unselectedLabelColor: Theme.of(
                  context,
                ).colorScheme.onSurfaceVariant,
                indicatorColor: Theme.of(context).colorScheme.primary,
                tabs: [
                  for (final tab in tabs)
                    Tab(
                      text: tab.isAll
                          ? 'All ${tab.count}'
                          : '${tab.emoji} ${tab.count}',
                    ),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    for (final tab in tabs)
                      _ReactorList(
                        messageId: messageId,
                        rows: reactionDetailRows(groups: groups, tab: tab),
                        showEmoji: tab.isAll,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReactorList extends ConsumerWidget {
  const _ReactorList({
    required this.messageId,
    required this.rows,
    required this.showEmoji,
  });

  final String messageId;
  final List<ReactionDetailRow> rows;
  final bool showEmoji;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (rows.isEmpty) {
      return Center(
        child: Text(
          'No one yet',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }
    final chat = ref.watch(chatProvider);
    final me = chat.currentUserId;
    final known = reactorAvatarIndex(
      chat,
      selfAvatar: ref.watch(profileProvider).valueOrNull?.avatarUrl,
    );
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
      itemCount: rows.length,
      separatorBuilder: (_, _) => const SizedBox(height: 2),
      itemBuilder: (context, i) {
        final row = rows[i];
        final isMe = row.userId == me;
        final name = _displayName(ref, row, isMe);
        final avatar = reactorAvatarUrl(
          userId: row.userId,
          fromReaction: row.avatarUrl,
          known: known,
        );
        return ListTile(
          leading: AppAvatar(size: 40, url: avatar, name: name),
          title: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          trailing: showEmoji
              ? Text(row.emoji, style: const TextStyle(fontSize: 20))
              : null,
          onTap: () {
            if (isMe) {
              ref
                  .read(chatProvider.notifier)
                  .toggleReaction(messageId, row.emoji);
              return;
            }
            showUserProfileSheet(
              context: context,
              ref: ref,
              userId: row.userId,
              userName: name,
              userAvatarUrl: avatar,
            );
          },
        );
      },
    );
  }

  String _displayName(WidgetRef ref, ReactionDetailRow row, bool isMe) {
    if (isMe) return 'You';
    final nick = ref
        .read(contactNicknamesProvider)
        .resolve(
          userId: row.userId,
          name: row.name.isEmpty ? null : row.name,
          fallback: '',
        );
    if (nick.trim().isNotEmpty) return nick;
    final chat = ref.read(chatProvider);
    final conv = chat.conversationById(chat.activeConversationId);
    if (conv != null &&
        conv.peerUserId == row.userId &&
        (conv.peerUserName ?? '').trim().isNotEmpty) {
      return conv.peerUserName!.trim();
    }
    return 'Someone';
  }
}

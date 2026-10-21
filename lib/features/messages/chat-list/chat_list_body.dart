import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/shell_bottom_bar/shell_pill_metrics.dart';
import '../../home/pages/home_drafts_list.dart';
import '../../local_share/data/share_thread_queries.dart';
import '../add-friends/add_friends_sheet.dart';
import '../chat_list_filters.dart';
import '../data/models/chat_models.dart';
import '../providers/chat_provider.dart';
import 'add_friends_row.dart';
import 'chat_list_entries.dart';
import 'conversation_rows.dart';
import 'list_empty.dart';

/// What sits under the tabs: the rows of the chosen tab, the drafts list
/// for Drafts, or that tab's empty state. All also leads with Add new
/// friends, empty or not.
class ChatListBody extends ConsumerWidget {
  const ChatListBody({
    super.key,
    required this.filter,
    required this.entries,
    required this.loading,
    required this.currentUserId,
    required this.onShowAll,
    required this.onLongPress,
    required this.onShareLongPress,
  });

  final ChatListFilter filter;
  final List<ChatListEntry> entries;
  final bool loading;
  final String? currentUserId;
  final VoidCallback onShowAll;
  final void Function(ChatConversation) onLongPress;
  final void Function(ShareThread) onShareLongPress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (filter == ChatListFilter.drafts) {
      return HomeDraftsList(
        bottomPadding: ShellPillMetrics.contentBottom(context),
      );
    }
    if (loading && entries.isEmpty) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2.5));
    }
    final addFriends = filter == ChatListFilter.all
        ? AddFriendsRow(onTap: () => showAddFriendsSheet(context, ref))
        : null;
    if (entries.isEmpty) {
      final empty = ConversationListEmpty(
        filter: filter,
        onStart: () => context.push('/messages/new'),
        onShowAll: onShowAll,
        onFindDevices: () => context.push('/local-share'),
      );
      if (addFriends == null) return empty;
      return Column(
        children: [
          addFriends,
          Expanded(child: empty),
        ],
      );
    }
    return ConversationRows(
      entries: entries,
      header: addFriends,
      currentUserId: currentUserId,
      onRefresh: () => ref.read(chatProvider.notifier).fetchSidebar(),
      onTap: (c) => context.push('/messages/${c.id}'),
      onLongPress: onLongPress,
      onShareTap: (t) => context.push('/local-share/${t.device.deviceId}'),
      onShareLongPress: onShareLongPress,
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/shell_bottom_bar/shell_pill_metrics.dart';
import '../../../core/router/shell_bottom_bar/shell_chrome_provider.dart';
import '../chat-sidebar/new_dm_dialog.dart';
import '../chat_list_filters.dart';
import '../providers/chat_provider.dart';
import 'compose_sheet.dart';
import 'conversation_rows.dart';
import 'create_channel_dialog.dart';
import 'filter_chips_row.dart';
import 'list_fab.dart';
import 'list_header.dart';
import 'recent_contacts_strip.dart';

class ChatList extends ConsumerStatefulWidget {
  const ChatList({super.key});

  @override
  ConsumerState<ChatList> createState() => _ChatListState();
}

class _ChatListState extends ConsumerState<ChatList> {
  ChatListFilter _filter = ChatListFilter.all;

  @override
  Widget build(BuildContext context) {
    final chat = ref.watch(chatProvider);
    final rows = unifiedConversations(
      dms: chat.dms,
      channels: chat.channels,
      filter: _filter,
    );
    final recent = recentDmsForStrip(chat.dms);

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const ChatListHeader(),
            if (recent.isNotEmpty)
              RecentContactsStrip(
                conversations: recent,
                currentUserId: chat.currentUserId,
                onTap: (c) => context.push('/messages/${c.id}'),
              ),
            FilterChipsRow(
              filter: _filter,
              onChanged: (f) => setState(() => _filter = f),
            ),
            Expanded(
              child: chat.sidebarLoading && rows.isEmpty
                  ? const Center(
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : ConversationRows(
                      conversations: rows,
                      currentUserId: chat.currentUserId,
                      onRefresh: () =>
                          ref.read(chatProvider.notifier).fetchSidebar(),
                      onTap: (c) => context.push('/messages/${c.id}'),
                      onMarkRead: (c) => ref
                          .read(chatProvider.notifier)
                          .markConversationRead(c.id),
                      onLeaveChannel: (c) =>
                          ref.read(chatProvider.notifier).leaveChannel(c.id),
                      onRemoveDm: (c) =>
                          ref.read(chatProvider.notifier).hideDm(c.id),
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(
          bottom: ShellPillMetrics.contentBottomInset - 24,
        ),
        child: ChatListFab(onPressed: () => _compose(context)),
      ),
    );
  }

  Future<void> _compose(BuildContext context) async {
    final shellChrome = ref.read(shellBottomBarHiddenProvider.notifier);
    shellChrome.state = true;
    try {
      final action = await showComposeSheet(context);
      if (!context.mounted || action == null) return;
      if (action == 'dm') {
        final dm = await showNewDmDialog(context, ref);
        if (dm != null && context.mounted) context.push('/messages/${dm.id}');
      } else if (action == 'channel' || action == 'group') {
        final ch = await showCreateChannelDialog(context, ref);
        if (ch != null && context.mounted) context.push('/messages/${ch.id}');
      }
    } finally {
      shellChrome.state = false;
    }
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/shell_bottom_bar/shell_chrome_provider.dart';
import '../../../core/router/shell_bottom_bar/shell_pill_metrics.dart';
import '../../local_share/data/share_thread_queries.dart';
import '../../local_share/providers/share_in_chats.dart';
import '../../local_share/sheets/share_chat_row_sheet.dart';
import '../chat_list_filters.dart';
import '../message_e2ee/new_chat_setup.dart';
import '../data/models/chat_models.dart';
import '../providers/chat_provider.dart';
import '../nickname/contact_nickname_provider.dart';
import '../nickname/nickname_title.dart';
import 'camera_send_flow.dart';
import 'chat_list_entries.dart';
import 'conversation_actions_run.dart';
import 'conversation_actions_sheet.dart';
import 'filter_chips_row.dart';
import 'conversation_rows.dart';
import 'list_fab.dart';
import 'list_header.dart';
import 'list_empty.dart';
import 'recent_contacts_strip.dart';
import '../../chat-lock/chat_lock_filter.dart';
import '../../chat-lock/providers/chat_locks_provider.dart';

class ChatList extends ConsumerStatefulWidget {
  const ChatList({super.key, this.banner});

  final Widget? banner;

  @override
  ConsumerState<ChatList> createState() => _ChatListState();
}

class _ChatListState extends ConsumerState<ChatList> {
  ChatListFilter _filter = ChatListFilter.all;

  /// Long press on a row. The sheet only chooses; the action runs here, on
  /// the list's own context, because the sheet is gone before the request
  /// comes back and the pin cap is reported after it.
  ///
  /// The floating nav pill is a `Positioned` in the shell's Stack, painted
  /// OVER this branch's navigator — so a sheet raised from here comes up
  /// underneath it, scrim and all. Hiding the bar covers BOTH the chooser
  /// and any follow-up sheet (mute options): restoring it in between would
  /// paint the pill over the mute sheet. The `finally` is load-bearing — a
  /// sheet dismissed by a back gesture must not leave the app with no nav.
  Future<void> _openActions(ChatConversation conversation) async {
    final title = ref
        .read(contactNicknamesProvider)
        .titleFor(conversation, ref.read(chatProvider).currentUserId);
    final hidden = ref.read(shellBottomBarHiddenProvider.notifier);
    hidden.state = true;
    try {
      final action = await showConversationActionsSheet(
        context,
        conversation,
        title,
      );
      if (action == null || !mounted) return;
      await runConversationAction(context, ref, conversation, title, action);
    } finally {
      hidden.state = false;
    }
  }

  /// Same nav-pill rule as [_openActions]: the sheet must not come up under it.
  Future<void> _openShareActions(ShareThread thread) async {
    final hidden = ref.read(shellBottomBarHiddenProvider.notifier);
    hidden.state = true;
    try {
      await showShareChatRowSheet(context, ref, thread);
    } finally {
      hidden.state = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final original = ref.watch(chatProvider);
    final chat = ref.watch(newChatSetupProvider).pending
        ? original.copyWith(
            dms: original.dms.map((c) => c.withoutMessagePreview()).toList(),
            channels: original.channels
                .map((c) => c.withoutMessagePreview())
                .toList(),
          )
        : original;
    // Locked chats live behind a long press on the title, nowhere here.
    final locks = ref.watch(chatLocksProvider);
    final dms = withoutLockedChats(chat.dms, locks);
    final channels = withoutLockedChats(chat.channels, locks);
    final shareThreads = ref.watch(shareChatThreadsProvider);
    final filters = availableChatListFilters([
      ...dms,
      ...channels,
    ], hasShareThreads: shareThreads.isNotEmpty);
    // A pill whose last chat went away (read the last unread, left the last
    // group) takes the selection back to All rather than an empty list.
    if (!filters.contains(_filter)) _filter = ChatListFilter.all;
    // Local Share device threads the user moved here sit among the chats.
    final rows = mergeChatListEntries(
      conversations: unifiedConversations(
        dms: dms,
        channels: channels,
        filter: _filter,
      ),
      threads: shareThreads,
      filter: _filter,
    );
    final recentDms = recentDmsForStrip(dms);
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const ChatListHeader(),
            if (widget.banner != null) widget.banner!,
            // Avatar rail first, pills under it — Slack's order. The pills
            // filter the list below them, so they sit against it.
            if (recentDms.isNotEmpty)
              RecentContactsStrip(
                conversations: recentDms,
                currentUserId: chat.currentUserId,
                onTap: (conversation) =>
                    context.push('/messages/${conversation.id}'),
              ),
            FilterChipsRow(
              filters: filters,
              filter: _filter,
              onChanged: (next) => setState(() => _filter = next),
            ),
            Expanded(
              child: chat.sidebarLoading && rows.isEmpty
                  ? const Center(
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : rows.isEmpty
                  ? ConversationListEmpty(
                      filter: _filter,
                      onStart: () => context.push('/messages/new'),
                      onShowAll: () =>
                          setState(() => _filter = ChatListFilter.all),
                    )
                  : ConversationRows(
                      entries: rows,
                      currentUserId: chat.currentUserId,
                      onRefresh: () =>
                          ref.read(chatProvider.notifier).fetchSidebar(),
                      onTap: (c) => context.push('/messages/${c.id}'),
                      onLongPress: _openActions,
                      onShareTap: (t) =>
                          context.push('/local-share/${t.device.deviceId}'),
                      onShareLongPress: _openShareActions,
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: Padding(
        padding: EdgeInsets.only(
          bottom: ShellPillMetrics.contentBottom(context) - 24,
        ),
        child: ChatListFab(
          onCamera: () => captureAndSendChatPhoto(context, ref),
          onNewMessage: () => context.push('/messages/new'),
        ),
      ),
    );
  }
}

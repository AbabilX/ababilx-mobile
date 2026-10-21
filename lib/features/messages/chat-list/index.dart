import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/shell_bottom_bar/shell_chrome_provider.dart';
import '../../../core/router/shell_bottom_bar/shell_pill_metrics.dart';
import '../../../core/router/shell_bottom_bar/tab_reselect.dart';
import '../../local_share/data/share_thread_queries.dart';
import '../../local_share/providers/share_chat_pins.dart';
import '../../local_share/providers/share_in_chats.dart';
import '../../local_share/sheets/share_chat_row_sheet.dart';
import '../add-friends/add_friends_pending.dart';
import '../chat_list_filters.dart';
import '../message_e2ee/new_chat_setup.dart';
import '../data/models/chat_models.dart';
import '../providers/chat_provider.dart';
import '../nickname/contact_nickname_provider.dart';
import '../nickname/nickname_title.dart';
import 'camera_send_flow.dart';
import 'chat_list_body.dart';
import 'chat_list_entries.dart';
import 'conversation_actions_run.dart';
import 'conversation_actions_sheet.dart';
import 'filter_chips_row.dart';
import 'filter_reorder_blur.dart';
import 'list_fab.dart';
import 'list_header.dart';
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
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => offerAddFriendsIfDue(context, ref),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(addFriendsAfterOnboardingProvider, (_, due) {
      if (!due) return;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => offerAddFriendsIfDue(context, ref),
      );
    });
    ref.listen(tabReselectProvider, (_, tap) {
      if (tap?.route != '/messages') return;
      setState(
        () => _filter = _filter == ChatListFilter.unread
            ? ChatListFilter.all
            : ChatListFilter.unread,
      );
    });
    final original = ref.watch(chatProvider);
    final chat = ref.watch(newChatSetupProvider).pending
        ? original.copyWith(
            dms: original.dms.map((c) => c.withoutMessagePreview()).toList(),
            channels: original.channels
                .map((c) => c.withoutMessagePreview())
                .toList(),
          )
        : original;
    // Locked chats live behind their pill and the title's long press.
    final locks = ref.watch(chatLocksProvider);
    final dms = withoutLockedChats(chat.dms, locks);
    final channels = withoutLockedChats(chat.channels, locks);
    // Local Share tab: every device thread, not only those moved here.
    final shareThreads = ref.watch(
      _filter == ChatListFilter.localShare
          ? shareTabThreadsProvider
          : shareChatThreadsProvider,
    );
    final filters = availableChatListFilters([
      ...dms,
      ...channels,
    ], hasLocked: locks.isNotEmpty);
    // Unread gone, or a tab that opens a page.
    if (!filters.contains(_filter) || isChatListFilterAction(_filter)) {
      _filter = ChatListFilter.all;
    }
    // Local Share device threads the user moved here sit among the chats.
    final rows = mergeChatListEntries(
      conversations: unifiedConversations(
        dms: dms,
        channels: channels,
        filter: _filter,
      ),
      threads: shareThreads,
      filter: _filter,
      pinnedThreads: ref.watch(shareChatPinsProvider).valueOrNull ?? const {},
    );
    final recentDms = recentDmsForStrip(dms);
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const FilterReorderBlur(child: ChatListHeader()),
            if (widget.banner != null) FilterReorderBlur(child: widget.banner!),
            // Avatar rail first, pills under it — Slack's order. The pills
            // filter the list below them, so they sit against it.
            if (recentDms.isNotEmpty)
              FilterReorderBlur(
                child: RecentContactsStrip(
                  conversations: recentDms,
                  currentUserId: chat.currentUserId,
                  onTap: (conversation) =>
                      context.push('/messages/${conversation.id}'),
                ),
              ),
            FilterChipsRow(
              filters: filters,
              filter: _filter,
              onChanged: (next) => setState(() => _filter = next),
            ),
            Expanded(
              child: FilterReorderBlur(
                child: ChatListBody(
                  filter: _filter,
                  entries: rows,
                  loading: chat.sidebarLoading,
                  currentUserId: chat.currentUserId,
                  onShowAll: () => setState(() => _filter = ChatListFilter.all),
                  onLongPress: _openActions,
                  onShareLongPress: _openShareActions,
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: Padding(
        padding: EdgeInsets.only(
          bottom: ShellPillMetrics.contentBottom(context) - 24,
        ),
        child: FilterReorderBlur(
          child: ChatListFab(
            onCamera: () => captureAndSendChatPhoto(context, ref),
            onNewMessage: () => context.push('/messages/new'),
          ),
        ),
      ),
    );
  }
}

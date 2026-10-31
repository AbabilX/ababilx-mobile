import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/shell_bottom_bar/shell_pill_metrics.dart';
import '../../../core/router/shell_bottom_bar/tab_reselect.dart';
import '../../local_share/providers/share_chat_pins.dart';
import '../../local_share/providers/share_in_chats.dart';
import '../add-friends/add_friends_pending.dart';
import '../chat_list_filters.dart';
import '../message_e2ee/new_chat_setup.dart';
import '../data/models/chat_models.dart';
import '../providers/chat_sidebar_slice.dart';
import 'camera_send_flow.dart';
import 'chat_list_body.dart';
import 'chat_list_entries.dart';
import '../chat-folders/chat_folders.dart';
import '../../home/data/home_drafts.dart';
import 'chat_list_sheets.dart';
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

  /// A user folder shown instead of a built-in tab.
  String? _folderId;

  Future<void> _newFolder() async {
    final id = await openFolderSheet(context, ref);
    if (id != null && mounted) setState(() => _folderId = id);
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
      setState(() {
        _folderId = null;
        _filter = _filter == ChatListFilter.unread
            ? ChatListFilter.all
            : ChatListFilter.unread;
      });
    });
    // The sidebar slice only: this list stays built behind an open chat.
    final chat = ref.watch(chatSidebarProvider);
    final hidePreviews = ref.watch(newChatSetupProvider).pending;
    List<ChatConversation> shown(List<ChatConversation> list) => hidePreviews
        ? list.map((c) => c.withoutMessagePreview()).toList()
        : list;
    // Locked chats live behind their pill and the title's long press.
    final locks = ref.watch(chatLocksProvider);
    final dms = withoutLockedChats(shown(chat.dms), locks);
    final channels = withoutLockedChats(shown(chat.channels), locks);
    // Local Share tab: every device thread, not only those moved here.
    final shareThreads = ref.watch(
      _filter == ChatListFilter.localShare
          ? shareTabThreadsProvider
          : shareChatThreadsProvider,
    );
    final filters = availableChatListFilters(
      [...dms, ...channels],
      hasLocked: locks.isNotEmpty,
      hasLocalShare: ref.watch(shareTabThreadsProvider).isNotEmpty,
      // Local drafts only: scheduled messages would cost a request per
      // list build, and the Drafts tab still lists them once opened.
      hasDrafts: ref.watch(homeDraftsProvider).valueOrNull?.isNotEmpty ?? false,
    );
    final folders = ref.watch(chatFoldersProvider);
    final folder = folders.where((f) => f.id == _folderId).firstOrNull;
    if (folder == null) _folderId = null;
    // Unread gone, or a tab that opens a page.
    if (!filters.contains(_filter) || isChatListFilterAction(_filter)) {
      _filter = ChatListFilter.all;
    }
    // Local Share device threads the user moved here sit among the chats.
    final rows = mergeChatListEntries(
      conversations: folder != null
          ? [
              for (final c in unifiedConversations(
                dms: dms,
                channels: channels,
              ))
                if (folder.ids.contains(c.id)) c,
            ]
          : unifiedConversations(dms: dms, channels: channels, filter: _filter),
      threads: folder != null ? const [] : shareThreads,
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
              onChanged: (next) => setState(() {
                _folderId = null;
                _filter = next;
              }),
              folders: folders,
              folderId: _folderId,
              onFolder: (id) => setState(() => _folderId = id),
              onNewFolder: _newFolder,
              onEditFolder: (f) => openFolderSheet(context, ref, f),
            ),
            Expanded(
              child: FilterReorderBlur(
                child: ChatListBody(
                  filter: folder != null ? ChatListFilter.all : _filter,
                  folder: folder,
                  onEditFolder: () => openFolderSheet(context, ref, folder),
                  entries: rows,
                  loading: chat.sidebarLoading,
                  currentUserId: chat.currentUserId,
                  onShowAll: () => setState(() {
                    _folderId = null;
                    _filter = ChatListFilter.all;
                  }),
                  onLongPress: (c) => openConversationActions(context, ref, c),
                  onShareLongPress: (t) => openShareActions(context, ref, t),
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

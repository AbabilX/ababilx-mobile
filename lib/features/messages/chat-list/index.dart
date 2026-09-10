import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/shell_bottom_bar/shell_chrome_provider.dart';
import '../../../core/router/shell_bottom_bar/shell_pill_metrics.dart';
import '../chat_list_filters.dart';
import '../message_e2ee/new_chat_setup.dart';
import '../data/models/chat_models.dart';
import '../providers/chat_provider.dart';
import '../providers/chat_scope_provider.dart';
import '../../profile/providers/profile_provider.dart';
import '../nickname/contact_nickname_provider.dart';
import '../nickname/nickname_title.dart';
import 'camera_send_flow.dart';
import 'conversation_actions_run.dart';
import 'conversation_actions_sheet.dart';
import 'filter_chips_row.dart';
import 'conversation_rows.dart';
import 'list_fab.dart';
import 'list_header.dart';
import 'list_empty.dart';
import 'recent_contacts_strip.dart';

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
  /// underneath it, scrim and all. Hiding the bar for the duration is the
  /// shell's own answer to that (`shellBottomBarHiddenProvider`, same as the
  /// You sheet), and the `finally` is load-bearing: a sheet dismissed by a
  /// back gesture must not leave the app with no navigation.
  Future<void> _openActions(ChatConversation conversation) async {
    final title = ref
        .read(contactNicknamesProvider)
        .titleFor(conversation, ref.read(chatProvider).currentUserId);
    final hidden = ref.read(shellBottomBarHiddenProvider.notifier);
    ConversationAction? action;
    hidden.state = true;
    try {
      action = await showConversationActionsSheet(context, conversation, title);
    } finally {
      hidden.state = false;
    }
    if (action == null || !mounted) return;
    await runConversationAction(context, ref, conversation, title, action);
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
    final independent =
        ref.watch(profileProvider).valueOrNull?.independentChat ?? false;
    final scope = ref.watch(chatScopeProvider);
    final unscopedRows = unifiedConversations(
      dms: chat.dms,
      channels: chat.channels,
      filter: _filter,
    );
    final rows = !independent || scope == ChatScopeFilter.all
        ? unscopedRows
        : unscopedRows.where((conversation) {
            return scope == ChatScopeFilter.personal
                ? conversation.isPersonal
                : !conversation.isPersonal;
          }).toList();
    final scopedDms = !independent || scope == ChatScopeFilter.all
        ? chat.dms
        : chat.dms.where((conversation) {
            return scope == ChatScopeFilter.personal
                ? conversation.isPersonal
                : !conversation.isPersonal;
          }).toList();
    final recentDms = recentDmsForStrip(scopedDms);
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
                      onStart: () => context.push('/messages/new'),
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
                      onLongPress: _openActions,
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

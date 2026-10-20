import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../messages/chat-list/chat_list_entries.dart';
import '../../messages/chat-list/conversation_actions_run.dart';
import '../../messages/chat-list/conversation_actions_sheet.dart';
import '../../messages/chat-list/conversation_rows.dart';
import '../../messages/data/models/chat_models.dart';
import '../../messages/nickname/contact_nickname_provider.dart';
import '../../messages/nickname/nickname_title.dart';
import '../../messages/providers/chat_provider.dart';
import '../data/home_chats.dart';
import '../quick-views/quick_view_summary.dart';
import 'home_page_scaffold.dart';

/// Unread, Groups and Flock: the chat list's own rows, narrowed. Long press works
/// as it does in Messages (pin, mute, mark read, delete). The rows come from
/// the live sidebar, so a chat read elsewhere leaves Unread at once.
class HomeConversationsPage extends ConsumerWidget {
  const HomeConversationsPage.unread({super.key})
    : _kind = _Kind.unread,
      _titleKey = 'home_unread',
      _emptyKey = 'home_no_unread';

  const HomeConversationsPage.groups({super.key})
    : _kind = _Kind.groups,
      _titleKey = 'home_groups',
      _emptyKey = 'home_no_groups';

  const HomeConversationsPage.flock({super.key})
    : _kind = _Kind.flock,
      _titleKey = 'chat_filter_webhooks',
      _emptyKey = 'home_no_flock';

  final _Kind _kind;
  final String _titleKey;
  final String _emptyKey;

  Future<void> _actions(
    BuildContext context,
    WidgetRef ref,
    ChatConversation conversation,
  ) async {
    final title = ref
        .read(contactNicknamesProvider)
        .titleFor(conversation, ref.read(chatProvider).currentUserId);
    final action = await showConversationActionsSheet(
      context,
      conversation,
      title,
    );
    if (action == null || !context.mounted) return;
    await runConversationAction(context, ref, conversation, title, action);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = ref.watch(switch (_kind) {
      _Kind.unread => homeUnreadProvider,
      _Kind.groups => homeGroupsProvider,
      _Kind.flock => homeFlockProvider,
    });
    return HomePageScaffold(
      title: homeText(context, ref, _titleKey),
      body: rows.isEmpty
          ? HomePageEmpty(homeText(context, ref, _emptyKey))
          : ConversationRows(
              entries: [for (final c in rows) ConversationEntry(c)],
              currentUserId: ref.watch(
                chatProvider.select((s) => s.currentUserId),
              ),
              onRefresh: () => ref.read(chatProvider.notifier).fetchSidebar(),
              onTap: (c) => context.push('/messages/${c.id}'),
              onLongPress: (c) => _actions(context, ref, c),
              // No Local Share threads are listed here.
              onShareTap: (_) {},
              onShareLongPress: (_) {},
            ),
    );
  }
}

enum _Kind { unread, groups, flock }

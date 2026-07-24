import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/chat_provider.dart';
import '../data/models/chat_models.dart';
import 'conversation-list-item.dart';
import 'new-dm-dialog.dart';

class ChatSidebar extends ConsumerWidget {
  const ChatSidebar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chat = ref.watch(chatProvider);
    final notifier = ref.read(chatProvider.notifier);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Workspace',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
              IconButton(
                tooltip: 'Search',
                onPressed: () => _openSearch(context, ref),
                icon: const Icon(Icons.search_rounded),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.add_rounded),
                onSelected: (v) async {
                  if (v == 'channel') {
                    final created = await showCreateChannelDialog(context, ref);
                    if (created != null && context.mounted) {
                      context.push('/messages/${created.id}');
                    }
                  } else if (v == 'dm') {
                    final dm = await showNewDmDialog(context, ref);
                    if (dm != null && context.mounted) {
                      context.push('/messages/${dm.id}');
                    }
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'channel', child: Text('New channel')),
                  PopupMenuItem(value: 'dm', child: Text('New message')),
                ],
              ),
            ],
          ),
        ),
        if (chat.sidebarLoading && chat.channels.isEmpty && chat.dms.isEmpty)
          const Expanded(
            child: Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
          )
        else
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => notifier.fetchSidebar(),
              child: ListView(
                padding: const EdgeInsets.only(bottom: 100),
                children: [
                  _Section(
                    title: 'Channels',
                    conversations: chat.channels,
                    onTap: (c) => context.push('/messages/${c.id}'),
                    currentUserId: chat.currentUserId,
                  ),
                  _Section(
                    title: 'Direct messages',
                    conversations: chat.dms,
                    onTap: (c) => context.push('/messages/${c.id}'),
                    currentUserId: chat.currentUserId,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  void _openSearch(BuildContext context, WidgetRef ref) {
    showSearch<String?>(
      context: context,
      delegate: _ChatSearchDelegate(ref),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.conversations,
    required this.onTap,
    this.currentUserId,
  });

  final String title;
  final List<ChatConversation> conversations;
  final void Function(ChatConversation) onTap;
  final String? currentUserId;

  @override
  Widget build(BuildContext context) {
    if (conversations.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        ...conversations.map(
          (c) => ConversationListItem(
            conversation: c,
            currentUserId: currentUserId,
            onTap: () => onTap(c),
          ),
        ),
      ],
    );
  }
}

class _ChatSearchDelegate extends SearchDelegate<String?> {
  _ChatSearchDelegate(this.ref);

  final WidgetRef ref;

  @override
  List<Widget>? buildActions(BuildContext context) => [
        IconButton(icon: const Icon(Icons.clear), onPressed: () => query = ''),
      ];

  @override
  Widget? buildLeading(BuildContext context) => IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => close(context, null),
      );

  @override
  Widget buildResults(BuildContext context) => _buildList(context);

  @override
  Widget buildSuggestions(BuildContext context) {
    if (query.trim().length >= 2) {
      ref.read(chatProvider.notifier).searchMessages(query.trim());
    }
    return _buildList(context);
  }

  Widget _buildList(BuildContext context) {
    final chat = ref.watch(chatProvider);
    if (query.trim().length < 2) {
      return const Center(child: Text('Type at least 2 characters'));
    }
    if (chat.searchLoading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2.5));
    }
    if (chat.searchResults.isEmpty) {
      return const Center(child: Text('No messages found'));
    }
    return ListView.builder(
      itemCount: chat.searchResults.length,
      itemBuilder: (_, i) {
        final msg = chat.searchResults[i];
        return ListTile(
          title: Text(msg.userName ?? 'Unknown'),
          subtitle: Text(msg.body, maxLines: 2, overflow: TextOverflow.ellipsis),
          onTap: () {
            close(context, msg.conversationId);
            context.push('/messages/${msg.conversationId}');
          },
        );
      },
    );
  }
}

Future<ChatConversation?> showCreateChannelDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  final nameCtrl = TextEditingController();
  var isPrivate = false;
  return showDialog<ChatConversation>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: const Text('Create channel'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Channel name'),
              autofocus: true,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Private channel'),
              value: isPrivate,
              onChanged: (v) => setState(() => isPrivate = v),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              final channel = await ref
                  .read(chatProvider.notifier)
                  .createChannel(name: name, isPrivate: isPrivate);
              if (ctx.mounted) Navigator.pop(ctx, channel);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    ),
  );
}

Future<ChatConversation?> showNewDmDialog(
  BuildContext context,
  WidgetRef ref,
) {
  return showModalBottomSheet<ChatConversation>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => const NewDmSheet(),
  );
}

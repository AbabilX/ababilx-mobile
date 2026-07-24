import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../chat_icon.dart';
import '../providers/chat_provider.dart';
import '../tiptap_plain_text.dart';

void openChatSearch(BuildContext context, WidgetRef ref) {
  showSearch<String?>(
    context: context,
    delegate: ChatSearchDelegate(ref),
  );
}

class ChatSearchDelegate extends SearchDelegate<String?> {
  ChatSearchDelegate(this.ref);
  final WidgetRef ref;

  @override
  List<Widget>? buildActions(BuildContext context) => [
        IconButton(
          icon: const ChatIcon(HugeIcons.strokeRoundedCancel01),
          onPressed: () => query = '',
        ),
      ];

  @override
  Widget? buildLeading(BuildContext context) => IconButton(
        icon: const ChatIcon(HugeIcons.strokeRoundedArrowLeft01),
        onPressed: () => close(context, null),
      );

  @override
  Widget buildResults(BuildContext context) => _list(context);

  @override
  Widget buildSuggestions(BuildContext context) {
    if (query.trim().length >= 2) {
      ref.read(chatProvider.notifier).searchMessages(query.trim());
    }
    return _list(context);
  }

  Widget _list(BuildContext context) {
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
          subtitle: Text(
            tiptapToPlainText(msg.body),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          onTap: () {
            close(context, msg.conversationId);
            context.push('/messages/${msg.conversationId}');
          },
        );
      },
    );
  }
}

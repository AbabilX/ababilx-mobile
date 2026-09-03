import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../chat_icon.dart';
import '../providers/chat_provider.dart';
import '../tiptap_plain_text.dart';

void openChatSearch(
  BuildContext context,
  WidgetRef ref, {
  String? conversationId,
  String? conversationTitle,
}) {
  showSearch<String?>(
    context: context,
    delegate: ChatSearchDelegate(
      ref,
      conversationId: conversationId,
      conversationTitle: conversationTitle,
    ),
  );
}

class ChatSearchDelegate extends SearchDelegate<String?> {
  ChatSearchDelegate(this.ref, {this.conversationId, this.conversationTitle});
  final WidgetRef ref;

  /// Opened from one chat's details screen: the server search is account-wide,
  /// so the results are narrowed here rather than pretending to be global.
  final String? conversationId;
  final String? conversationTitle;

  @override
  String get searchFieldLabel => conversationTitle == null
      ? super.searchFieldLabel ?? 'Search'
      : 'Search in $conversationTitle';

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

  Widget _list(BuildContext context) => Consumer(
    builder: (_, ref, _) {
      final chat = ref.watch(chatProvider);
      if (query.trim().length < 2) {
        return const Center(child: Text('Type at least 2 characters'));
      }
      if (chat.searchLoading) {
        return const Center(child: CircularProgressIndicator(strokeWidth: 2.5));
      }
      final results = conversationId == null
          ? chat.searchResults
          : chat.searchResults
                .where((m) => m.conversationId == conversationId)
                .toList();
      if (results.isEmpty) {
        return const Center(child: Text('No messages found'));
      }
      return ListView.builder(
        itemCount: results.length,
        itemBuilder: (_, i) {
          final msg = results[i];
          return ListTile(
            title: Text(msg.userName ?? 'Unknown'),
            subtitle: Text(
              tiptapToPreviewText(msg.body),
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
    },
  );
}

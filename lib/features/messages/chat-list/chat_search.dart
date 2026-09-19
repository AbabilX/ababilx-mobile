import 'package:flutter/material.dart';
import 'package:ababilx/shared/widgets/app_bar_back_button.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/router/shell_bottom_bar/shell_chrome_provider.dart';
import '../chat_icon.dart';
import '../providers/chat_provider.dart';
import 'chat_search_results.dart';

Future<String?> openChatSearch(
  BuildContext context,
  WidgetRef ref, {
  String? conversationId,
  String? conversationTitle,
}) async {
  // showSearch sits on the shell navigator, so the floating pill would
  // otherwise paint over the results — same hide as the You sheet.
  final hidden = ref.read(shellBottomBarHiddenProvider.notifier);
  hidden.state = true;
  try {
    return await showSearch<String?>(
      context: context,
      delegate: ChatSearchDelegate(
        ref,
        conversationId: conversationId,
        conversationTitle: conversationTitle,
      ),
    );
  } finally {
    hidden.state = false;
  }
}

class ChatSearchDelegate extends SearchDelegate<String?> {
  ChatSearchDelegate(this.ref, {this.conversationId, this.conversationTitle});
  final WidgetRef ref;

  /// Opened from one chat's details screen: the server search is account-wide,
  /// so the message hits are narrowed here rather than pretending to be global.
  /// Name-matched sidebar chats stay global — the same two-section layout as
  /// the list search, which is how a person jumps to another chat from here.
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
    tooltip: MaterialLocalizations.of(context).backButtonTooltip,
    icon: const AppBarBackIcon(),
    onPressed: () => close(context, null),
  );

  @override
  Widget buildResults(BuildContext context) => _list(context);

  @override
  Widget buildSuggestions(BuildContext context) {
    final q = query.trim();
    // SearchDelegate rebuilds on every keystroke. Kicking the index off
    // during build is a Riverpod write-in-layout, so wait a frame and skip
    // a query we are already answering.
    if (q.length >= 2 && ref.read(chatProvider).searchQuery != q) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (query.trim() != q) return;
        ref.read(chatProvider.notifier).searchMessages(q);
      });
    }
    return _list(context);
  }

  Widget _list(BuildContext context) => ChatSearchResults(
    query: query,
    conversationId: conversationId,
    onOpenConversation: (id) {
      close(context, id);
      context.push('/messages/$id');
    },
  );
}

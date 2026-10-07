import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/localization/app_translations.dart';
import '../../chat-lock/providers/chat_locks_provider.dart';
import '../chat-details/details_tile.dart';
import '../chat_icon.dart';
import 'snippet_strings.dart';

/// "Snippets" on the details screen: every `.md` / `.txt` snippet sent in the
/// chat. Not drawn for a locked chat — the page reads files from disk, and a
/// locked chat keeps none there.
class SnippetsTile extends ConsumerWidget {
  const SnippetsTile({super.key, required this.conversationId});

  final String conversationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(isChatLockedProvider(conversationId))) {
      return const SizedBox.shrink();
    }
    return DetailsTile(
      icon: const ChatIcon(HugeIcons.strokeRoundedDocumentCode),
      title: SnippetStrings.of(ref.watch(appLanguageProvider)).snippets,
      trailing: const ChatIcon(HugeIcons.strokeRoundedArrowRight01, size: 18),
      onTap: () => context.push('/messages/$conversationId/snippets'),
    );
  }
}

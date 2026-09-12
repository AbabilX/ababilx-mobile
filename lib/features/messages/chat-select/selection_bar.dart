import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_translations.dart';
import '../data/models/chat_models.dart';
import '../providers/chat_provider.dart';
import 'message_selection.dart';
import 'selection_action_bar.dart';
import 'selection_actions.dart';

/// The selected messages as the timeline holds them right now, oldest first.
///
/// Resolved on every build rather than stored with the selection: an edit, a
/// send confirmation or a delete from another device all land here first, and
/// the bar must decide what it may offer from the row as it is.
List<ChatMessage> selectedMessagesIn(WidgetRef ref, String conversationId) {
  final selection = ref.watch(messageSelectionProvider);
  if (!selection.isActiveIn(conversationId)) return const [];
  final messages = ref
      .watch(chatProvider)
      .feedFor(conversationId)
      .messages
      .where((m) => selection.contains(m.id))
      .toList();
  messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
  return messages;
}

/// Signal's bottom action bar, in the composer's place while selecting.
class SelectionBar extends ConsumerWidget {
  const SelectionBar({super.key, required this.conversationId});

  final String conversationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = selectedMessagesIn(ref, conversationId);
    if (selected.isEmpty) return const SizedBox.shrink();
    final conversation = ref
        .watch(chatProvider)
        .conversationById(conversationId);
    final items = selectionActions(
      context: context,
      ref: ref,
      selected: selected,
      // Reply is the only action the composer lock reaches: a read-only feed
      // or a blocked DM can still have its messages forwarded and copied.
      canMessage: conversation?.canMessage ?? false,
    );
    if (items.isEmpty) return const SizedBox.shrink();
    return SelectionActionBar(
      items: items,
      moreLabel: AppTranslations.translate(context, ref, 'chat_more'),
    );
  }
}

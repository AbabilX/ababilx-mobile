import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/text/byte_size.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../attachments/storage/storage_providers.dart';
import '../../attachments/storage/storage_usage.dart';
import '../../messages/nickname/contact_nickname_provider.dart';
import '../../messages/nickname/nickname_title.dart';
import '../../messages/providers/chat_provider.dart';
import 'storage_confirm.dart';

/// Which chats the downloaded media belongs to, biggest first.
///
/// A file forwarded into three chats is counted in all three — the bytes exist
/// once, so these do not add up to the total above. Splitting them would
/// invent a number that is wrong whichever chat it is charged to.
class StorageChatList extends ConsumerWidget {
  const StorageChatList({super.key});

  /// Enough to find the chat that is costing something without turning the
  /// screen into a second conversation list.
  static const maxRows = 12;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = ref.watch(storageByConversationProvider);
    final theme = Theme.of(context);

    return rows.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: LinearProgressIndicator(),
      ),
      error: (_, _) => const SizedBox.shrink(),
      data: (all) {
        if (all.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Text(
              'No chat is using storage on this phone.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          );
        }
        final shown = all.take(maxRows).toList();
        return Column(
          children: [
            for (final row in shown) _ChatRow(row: row),
            if (all.length > shown.length)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Text(
                  '${all.length - shown.length} more chats not shown',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ChatRow extends ConsumerWidget {
  const _ChatRow({required this.row});

  final ConversationStorage row;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chat = ref.watch(chatProvider);
    final conversation = chat.conversationById(row.conversationId);
    final title = conversation == null
        ? 'Conversation'
        : ref
              .watch(contactNicknamesProvider)
              .titleFor(conversation, chat.currentUserId);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text('${row.count} files'),
      trailing: Text(
        formatBytes(row.bytes),
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
      onTap: () => _delete(context, ref, title),
    );
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    String title,
  ) async {
    final confirmed = await confirmStorageDelete(
      context,
      title: 'Delete media from $title?',
      body:
          'Frees about ${formatBytes(row.bytes)}. The messages stay — media '
          'can be downloaded again.',
    );
    if (!confirmed) return;
    final freed = await ref
        .read(storageManagerProvider)
        .releaseConversation(row.conversationId);
    invalidateStorage(ref);
    if (!context.mounted) return;
    showAppToast(context, 'Freed ${formatBytes(freed)}');
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/localization/app_translations.dart';
import '../chat_icon.dart';
import '../data/models/chat_models.dart';
import 'chat_folder_sheet.dart';
import 'chat_folders.dart';

/// Long press → Add to folder: tick the folders this chat belongs in, or
/// make a new one with it already inside.
Future<void> showAddToFolderSheet(
  BuildContext context,
  WidgetRef ref,
  ChatConversation conversation,
) async {
  final folders = ref.read(chatFoldersProvider);
  if (folders.isEmpty) {
    await _newWith(context, ref, conversation);
    return;
  }
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (_) => _AddToFolder(conversation: conversation),
  );
}

Future<void> _newWith(
  BuildContext context,
  WidgetRef ref,
  ChatConversation conversation,
) async {
  final id = await showChatFolderSheet(context);
  if (id == null) return;
  final folder = ref
      .read(chatFoldersProvider)
      .where((f) => f.id == id)
      .firstOrNull;
  if (folder == null) return;
  await ref
      .read(chatFoldersProvider.notifier)
      .update(id, ids: {...folder.ids, conversation.id});
}

class _AddToFolder extends ConsumerWidget {
  const _AddToFolder({required this.conversation});

  final ChatConversation conversation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    String t(String key) => AppTranslations.translate(context, ref, key);
    final folders = ref.watch(chatFoldersProvider);
    final notifier = ref.read(chatFoldersProvider.notifier);
    final mine = {
      for (final f in folders)
        if (f.ids.contains(conversation.id)) f.id,
    };
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(
              t('chat_folder_add_to'),
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          for (final f in folders)
            CheckboxListTile(
              value: mine.contains(f.id),
              onChanged: (on) => notifier.setFoldersFor(
                conversation.id,
                on == true ? {...mine, f.id} : ({...mine}..remove(f.id)),
              ),
              secondary: const ChatIcon(HugeIcons.strokeRoundedFolder01),
              title: Text(f.name, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          if (folders.length < maxChatFolders)
            ListTile(
              leading: const ChatIcon(HugeIcons.strokeRoundedFolderAdd),
              title: Text(t('chat_folder_new')),
              onTap: () async {
                final navigator = Navigator.of(context);
                await _newWith(context, ref, conversation);
                navigator.pop();
              },
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/localization/app_translations.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../chat-lock/chat_lock_filter.dart';
import '../../chat-lock/providers/chat_locks_provider.dart';
import '../chat-list/conversation_avatar.dart';
import '../chat_icon.dart';
import '../chat_list_filters.dart';
import '../nickname/contact_nickname_provider.dart';
import '../nickname/nickname_title.dart';
import '../providers/chat_provider.dart';
import 'chat_folders.dart';

/// New folder, or edit one: a name, then tick the chats that go in it.
/// Returns the folder's id once saved (null when dismissed or deleted).
Future<String?> showChatFolderSheet(
  BuildContext context, {
  ChatFolder? folder,
}) => showModalBottomSheet<String>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (_) => _FolderSheet(folder: folder),
);

class _FolderSheet extends ConsumerStatefulWidget {
  const _FolderSheet({this.folder});

  final ChatFolder? folder;

  @override
  ConsumerState<_FolderSheet> createState() => _FolderSheetState();
}

class _FolderSheetState extends ConsumerState<_FolderSheet> {
  late final _name = TextEditingController(text: widget.folder?.name ?? '');
  late final Set<String> _ids = {...?widget.folder?.ids};

  String t(String key) => AppTranslations.translate(context, ref, key);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    final folders = ref.read(chatFoldersProvider.notifier);
    final navigator = Navigator.of(context);
    final existing = widget.folder;
    if (existing != null) {
      await folders.update(existing.id, name: name, ids: _ids);
      navigator.pop(existing.id);
      return;
    }
    final made = await folders.create(name, _ids);
    if (made == null) {
      if (mounted) showAppToast(context, t('chat_folder_limit'), isError: true);
      return;
    }
    navigator.pop(made.id);
  }

  Future<void> _delete() async {
    await ref.read(chatFoldersProvider.notifier).remove(widget.folder!.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final chat = ref.watch(chatProvider);
    final locks = ref.watch(chatLocksProvider);
    final names = ref.watch(contactNicknamesProvider);
    // Locked chats stay behind their unlock, so they are not offered here.
    final chats = unifiedConversations(
      dms: withoutLockedChats(chat.dms, locks),
      channels: withoutLockedChats(chat.channels, locks),
    );
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    t(
                      widget.folder == null
                          ? 'chat_folder_new'
                          : 'chat_folder_edit',
                    ),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (widget.folder != null)
                  IconButton(
                    tooltip: t('chat_folder_delete'),
                    onPressed: _delete,
                    icon: ChatIcon(
                      HugeIcons.strokeRoundedDelete02,
                      color: colors.error,
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: _name,
              autofocus: widget.folder == null,
              maxLength: maxChatFolderName,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: t('chat_folder_name'),
                counterText: '',
                filled: true,
                fillColor: colors.surfaceContainerHighest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
            child: Text(
              '${t('chat_folder_chats')} · ${_ids.length}',
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(color: colors.onSurfaceVariant),
            ),
          ),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: chats.length,
              itemBuilder: (context, i) {
                final c = chats[i];
                final title = names.titleFor(c, chat.currentUserId);
                return CheckboxListTile(
                  value: _ids.contains(c.id),
                  onChanged: (on) => setState(
                    () => on == true ? _ids.add(c.id) : _ids.remove(c.id),
                  ),
                  secondary: ConversationAvatar(
                    conversation: c,
                    title: title,
                    size: 40,
                  ),
                  title: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: FilledButton(
              onPressed: _name.text.trim().isEmpty ? null : _save,
              child: Text(t('chat_folder_save')),
            ),
          ),
        ],
      ),
    );
  }
}

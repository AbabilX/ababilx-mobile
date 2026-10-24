import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/localization/app_translations.dart';
import '../../home/data/home_drafts.dart';
import '../chat-folders/chat_folders.dart';
import '../chat_list_filters.dart';
import 'filter_chip.dart';
import 'filter_order.dart';
import 'filter_reorder_blur.dart';

/// One horizontally scrollable row of tabs above the conversation list:
/// All | Unread (while any) | Drafts | Groups | Flock | Local Share | Locked
/// (while any lock), then the user's own folders and a + that makes one
/// (Telegram's folders). Every tab filters the list in place; only Locked
/// opens its page, because locked chats stay behind their unlock. Hold a
/// built-in pill to drag it; hold a folder to edit it.
///
/// Personal and Workspaces pills used to sit here too. Since the server's
/// migration 0145 every conversation is personal — no workspace owns one — so
/// Personal would always equal All and Workspaces would always be empty.
class FilterChipsRow extends ConsumerWidget {
  const FilterChipsRow({
    super.key,
    required this.filters,
    required this.filter,
    required this.onChanged,
    this.folders = const [],
    this.folderId,
    this.onFolder,
    this.onNewFolder,
    this.onEditFolder,
  });

  final List<ChatListFilter> filters;
  final ChatListFilter filter;
  final ValueChanged<ChatListFilter> onChanged;
  final List<ChatFolder> folders;

  /// The folder shown, or null for a built-in tab.
  final String? folderId;
  final ValueChanged<String>? onFolder;
  final VoidCallback? onNewFolder;
  final ValueChanged<ChatFolder>? onEditFolder;

  static const _labels = {
    ChatListFilter.all: 'chat_all',
    ChatListFilter.unread: 'chat_unread',
    ChatListFilter.groups: 'chat_groups',
    ChatListFilter.webhooks: 'chat_filter_webhooks',
    ChatListFilter.localShare: 'chat_filter_local_share',
    ChatListFilter.drafts: 'home_drafts',
    ChatListFilter.locked: 'home_locked',
  };

  static final _icons = {
    ChatListFilter.unread: HugeIcons.strokeRoundedMailOpen01,
    ChatListFilter.groups: HugeIcons.strokeRoundedUserGroup,
    ChatListFilter.webhooks: HugeIcons.strokeRoundedWebhook,
    ChatListFilter.localShare: HugeIcons.strokeRoundedWifi01,
    ChatListFilter.drafts: HugeIcons.strokeRoundedSent,
    ChatListFilter.locked: HugeIcons.strokeRoundedSquareLock02,
  };

  /// The one tab that is a page.
  static const _actionRoutes = {ChatListFilter.locked: '/messages/locked'};

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (filters.isEmpty) return const SizedBox.shrink();
    final ordered = applyFilterOrder(filters, ref.watch(filterOrderProvider));
    String t(String key) => AppTranslations.translate(context, ref, key);
    Widget chip(ChatListFilter option) => FilterChipPill(
      label: t(_labels[option]!),
      icon: _icons[option],
      selected:
          folderId == null &&
          !isChatListFilterAction(option) &&
          option == filter,
      onTap: () async {
        final route = _actionRoutes[option];
        if (route != null) {
          await context.push(route);
          return;
        }
        // Drafts are re-read each time the tab is opened: a composer writes
        // as the person types, and nothing else tells this list.
        if (option == ChatListFilter.drafts) {
          ref.invalidate(homeDraftsProvider);
          ref.invalidate(homeScheduledProvider);
        }
        if (option != filter || folderId != null) onChanged(option);
      },
    );
    // Hold a pill and drag to arrange them. All stays first, so it is not
    // wrapped in a drag listener and nothing may be dropped before it.
    return SizedBox(
      height: 36,
      child: ReorderableListView.builder(
        scrollDirection: Axis.horizontal,
        buildDefaultDragHandles: false,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
        itemCount: ordered.length + folders.length + 1,
        proxyDecorator: (child, _, _) =>
            Material(color: Colors.transparent, child: child),
        onReorderStart: (_) => filterReordering.value = true,
        onReorderEnd: (_) => filterReordering.value = false,
        onReorderItem: (from, to) {
          // Folders and the + stay after the built-in pills.
          if (from >= ordered.length) return;
          if (to > ordered.length) to = ordered.length;
          final first = ordered.first == ChatListFilter.all;
          if (from == 0 && first) return;
          if (to == 0 && first) to = 1;
          if (from == to) return;
          final next = [...ordered];
          next.insert(to, next.removeAt(from));
          ref.read(filterOrderProvider.notifier).save(next);
        },
        itemBuilder: (context, i) {
          if (i >= ordered.length) return _folderChip(t, i - ordered.length);
          final option = ordered[i];
          final item = Padding(
            padding: const EdgeInsets.only(right: 8),
            child: chip(option),
          );
          return option == ChatListFilter.all
              ? KeyedSubtree(key: ValueKey(option), child: item)
              : ReorderableDelayedDragStartListener(
                  key: ValueKey(option),
                  index: i,
                  child: item,
                );
        },
      ),
    );
  }

  Widget _folderChip(String Function(String) t, int i) {
    final Widget pill;
    if (i == folders.length) {
      if (folders.length >= maxChatFolders) return const SizedBox.shrink();
      pill = FilterChipPill(
        label: t('chat_folder_new'),
        icon: HugeIcons.strokeRoundedFolderAdd,
        selected: false,
        onTap: () => onNewFolder?.call(),
      );
    } else {
      final f = folders[i];
      pill = FilterChipPill(
        label: f.name,
        icon: HugeIcons.strokeRoundedFolder01,
        selected: f.id == folderId,
        onTap: () => onFolder?.call(f.id),
        onLongPress: () => onEditFolder?.call(f),
      );
    }
    return KeyedSubtree(
      key: ValueKey(
        i == folders.length ? 'folder:+' : 'folder:${folders[i].id}',
      ),
      child: Padding(padding: const EdgeInsets.only(right: 8), child: pill),
    );
  }
}

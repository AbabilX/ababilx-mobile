import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/localization/app_translations.dart';
import '../chat_icon.dart';
import '../chat_list_filters.dart';
import 'filter_order.dart';

/// One horizontally scrollable row of pills above the conversation list:
/// All | Unread messages | Groups | Flock (webhook feeds; Ababil = a flock
/// of birds) — each only while something is behind it
/// (`availableChatListFilters`), and the row is gone when All would be the
/// only pill.
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
  });

  final List<ChatListFilter> filters;
  final ChatListFilter filter;
  final ValueChanged<ChatListFilter> onChanged;

  static const _labels = {
    ChatListFilter.all: 'chat_all',
    ChatListFilter.unread: 'chat_unread',
    ChatListFilter.groups: 'chat_groups',
    ChatListFilter.webhooks: 'chat_filter_webhooks',
    ChatListFilter.localShare: 'chat_filter_local_share',
  };

  static final _icons = {
    ChatListFilter.unread: HugeIcons.strokeRoundedMailOpen01,
    ChatListFilter.groups: HugeIcons.strokeRoundedUserGroup,
    ChatListFilter.webhooks: HugeIcons.strokeRoundedWebhook,
    ChatListFilter.localShare: HugeIcons.strokeRoundedWifi01,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (filters.isEmpty) return const SizedBox.shrink();
    final ordered = applyFilterOrder(filters, ref.watch(filterOrderProvider));
    Widget chip(ChatListFilter option) => _Chip(
      label: AppTranslations.translate(context, ref, _labels[option]!),
      icon: _icons[option],
      selected: option == filter,
      onTap: () {
        if (option != filter) onChanged(option);
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
        itemCount: ordered.length,
        proxyDecorator: (child, _, _) =>
            Material(color: Colors.transparent, child: child),
        onReorderItem: (from, to) {
          final first = ordered.first == ChatListFilter.all;
          if (from == 0 && first) return;
          if (to == 0 && first) to = 1;
          if (from == to) return;
          final next = [...ordered];
          next.insert(to, next.removeAt(from));
          ref.read(filterOrderProvider.notifier).save(next);
        },
        itemBuilder: (context, i) {
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
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final List<List<dynamic>>? icon;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: selected ? colors.surfaceContainerHighest : Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? Colors.transparent : colors.outlineVariant,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                ChatIcon(icon!, size: 14, color: colors.onSurfaceVariant),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: TextStyle(
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 12,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

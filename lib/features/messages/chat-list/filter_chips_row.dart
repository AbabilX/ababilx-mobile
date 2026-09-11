import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/localization/app_translations.dart';
import '../chat_icon.dart';
import '../chat_list_filters.dart';

/// One horizontally scrollable row of pills above the conversation list:
/// All | Unread messages.
///
/// Personal and Workspaces pills used to sit here too. Since the server's
/// migration 0145 every conversation is personal — no workspace owns one — so
/// Personal would always equal All and Workspaces would always be empty.
class FilterChipsRow extends ConsumerWidget {
  const FilterChipsRow({
    super.key,
    required this.filter,
    required this.onChanged,
  });

  final ChatListFilter filter;
  final ValueChanged<ChatListFilter> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = filter == ChatListFilter.unread;

    void select(ChatListFilter next) {
      if (next != filter) onChanged(next);
    }

    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
        children: [
          _Chip(
            label: AppTranslations.translate(context, ref, 'chat_all'),
            selected: !unread,
            onTap: () => select(ChatListFilter.all),
          ),
          const SizedBox(width: 8),
          _Chip(
            label: AppTranslations.translate(context, ref, 'chat_unread'),
            icon: HugeIcons.strokeRoundedMailOpen01,
            selected: unread,
            onTap: () => select(ChatListFilter.unread),
          ),
        ],
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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/localization/app_translations.dart';
import '../chat_icon.dart';
import '../chat_list_filters.dart';
import '../providers/chat_scope_provider.dart';
import '../../profile/providers/profile_provider.dart';

/// One horizontally scrollable row of pills above the conversation list,
/// Slack-style: All | Unread messages | Personal | Workspaces.
///
/// Selection is single, not two orthogonal toggles. Unread-inside-Workspaces
/// would need a second selected pill and there is nowhere on a phone row to
/// show which of the two is active, so picking any pill resets the other axis
/// — the same trade Slack makes with VIP/External.
///
/// The scope pills only exist for a user whose account has independent chat;
/// without it every conversation is a workspace one and the pills would filter
/// nothing.
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
    final scope = ref.watch(chatScopeProvider);
    final independent =
        ref.watch(profileProvider).valueOrNull?.independentChat ?? false;
    final unread = filter == ChatListFilter.unread;

    void select(ChatListFilter next, ChatScopeFilter nextScope) {
      ref.read(chatScopeProvider.notifier).state = nextScope;
      if (next != filter) onChanged(next);
    }

    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        children: [
          _Chip(
            label: AppTranslations.translate(context, ref, 'chat_all'),
            selected: !unread && scope == ChatScopeFilter.all,
            onTap: () => select(ChatListFilter.all, ChatScopeFilter.all),
          ),
          const SizedBox(width: 8),
          _Chip(
            label: AppTranslations.translate(context, ref, 'chat_unread'),
            icon: HugeIcons.strokeRoundedMailOpen01,
            selected: unread,
            onTap: () => select(ChatListFilter.unread, ChatScopeFilter.all),
          ),
          if (independent) const SizedBox(width: 8),
          if (independent)
            _Chip(
              label: AppTranslations.translate(context, ref, 'chat_personal'),
              icon: HugeIcons.strokeRoundedUser,
              selected: !unread && scope == ChatScopeFilter.personal,
              onTap: () => select(ChatListFilter.all, ChatScopeFilter.personal),
            ),
          if (independent) const SizedBox(width: 8),
          if (independent)
            _Chip(
              label: AppTranslations.translate(context, ref, 'chat_workspaces'),
              icon: HugeIcons.strokeRoundedBuilding03,
              selected: !unread && scope == ChatScopeFilter.workspaces,
              onTap: () =>
                  select(ChatListFilter.all, ChatScopeFilter.workspaces),
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
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? Colors.transparent : colors.outlineVariant,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                ChatIcon(icon!, size: 16, color: colors.onSurfaceVariant),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

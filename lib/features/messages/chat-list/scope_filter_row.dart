import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_translations.dart';
import '../providers/chat_scope_provider.dart';

class ScopeFilterRow extends ConsumerWidget {
  const ScopeFilterRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(chatScopeProvider);
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
      ),
      child: Row(
        children: [
          _ScopeTab(
            label: AppTranslations.translate(context, ref, 'chat_all'),
            selected: selected == ChatScopeFilter.all,
            onTap: () => _select(ref, ChatScopeFilter.all),
          ),
          _ScopeTab(
            label: AppTranslations.translate(context, ref, 'chat_personal'),
            selected: selected == ChatScopeFilter.personal,
            onTap: () => _select(ref, ChatScopeFilter.personal),
          ),
          _ScopeTab(
            label: AppTranslations.translate(context, ref, 'chat_workspaces'),
            selected: selected == ChatScopeFilter.workspaces,
            onTap: () => _select(ref, ChatScopeFilter.workspaces),
          ),
        ],
      ),
    );
  }

  void _select(WidgetRef ref, ChatScopeFilter value) {
    ref.read(chatScopeProvider.notifier).state = value;
  }
}

class _ScopeTab extends StatelessWidget {
  const _ScopeTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: selected ? colors.primary : colors.onSurfaceVariant,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              height: 2,
              color: selected ? colors.primary : Colors.transparent,
            ),
          ],
        ),
      ),
    );
  }
}

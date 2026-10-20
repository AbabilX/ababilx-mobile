import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/localization/app_translations.dart';
import '../../../core/router/shell_bottom_bar/shell_tabs.dart';
import '../../messages/chat_icon.dart';
import 'start_tab.dart';

/// Bottom sheet: pick the tab the app opens on.
Future<void> showStartTabSheet(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (_) => const _StartTabSheet(),
  );
}

class _StartTabSheet extends ConsumerWidget {
  const _StartTabSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    String t(String key) => AppTranslations.translate(context, ref, key);
    final colors = Theme.of(context).colorScheme;
    final current = ref.watch(startTabProvider);
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 4),
            child: Text(
              t('settings_start_tab'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Text(
              t('settings_start_tab_sub'),
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
          ),
          for (final tab in homeShellTabs)
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 24),
              leading: ChatIcon(
                tab.route == current ? tab.selectedIcon : tab.icon,
                color: tab.route == current
                    ? colors.primary
                    : colors.onSurfaceVariant,
              ),
              title: Text(t(tab.labelKey)),
              trailing: tab.route == current
                  ? ChatIcon(
                      HugeIcons.strokeRoundedTick02,
                      color: colors.primary,
                    )
                  : null,
              onTap: () async {
                await ref.read(startTabProvider.notifier).choose(tab.route);
                if (context.mounted) Navigator.pop(context);
              },
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

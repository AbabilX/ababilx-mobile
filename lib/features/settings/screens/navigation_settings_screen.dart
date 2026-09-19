import 'package:flutter/material.dart';
import 'package:ababilx/shared/widgets/app_bar_back_button.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_translations.dart';
import '../../../core/router/shell_bottom_bar/shell_nav_prefs.dart';
import '../../messages/providers/team_gate_provider.dart';

/// Per-device toggles for which workspace tabs appear in the home bottom bar.
///
/// Reachable only when the account is on a team (hub row is gated by
/// [hasTeamProvider]). CRM's switch appears only when [canViewCrmProvider] is
/// true — hiding a tab the account cannot open would be noise.
class NavigationSettingsScreen extends ConsumerWidget {
  const NavigationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    String t(String key) => AppTranslations.translate(context, ref, key);
    final prefs = ref.watch(shellNavPrefsProvider);
    final showCrmAccess = ref.watch(canViewCrmProvider);
    final notifier = ref.read(shellNavPrefsProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        leading: const AppBarBackButton(),
        title: Text(t('settings_navigation')),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Text(
              t('settings_navigation_hint'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          SwitchListTile(
            value: prefs.showWall,
            onChanged: notifier.setShowWall,
            contentPadding: const EdgeInsets.symmetric(horizontal: 20),
            title: Text(t('wall'), style: theme.textTheme.titleSmall),
            subtitle: Text(
              t('settings_navigation_tab_sub'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          if (showCrmAccess)
            SwitchListTile(
              value: prefs.showCrm,
              onChanged: notifier.setShowCrm,
              contentPadding: const EdgeInsets.symmetric(horizontal: 20),
              title: Text(t('crm'), style: theme.textTheme.titleSmall),
              subtitle: Text(
                t('settings_navigation_tab_sub'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          SwitchListTile(
            value: prefs.showBoard,
            onChanged: notifier.setShowBoard,
            contentPadding: const EdgeInsets.symmetric(horizontal: 20),
            title: Text(t('board'), style: theme.textTheme.titleSmall),
            subtitle: Text(
              t('settings_navigation_tab_sub'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

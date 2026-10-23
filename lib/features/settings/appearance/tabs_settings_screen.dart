import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/localization/app_translations.dart';
import '../../../core/router/shell_bottom_bar/shell_tab_order.dart';
import '../../../core/router/shell_bottom_bar/shell_tabs.dart';
import '../../../shared/widgets/app_bar_back_button.dart';
import '../../messages/chat_icon.dart';
import '../../messages/group-member-permissions/permission_section.dart';
import '../start-tab/start_tab.dart';
import 'home_sections_settings.dart';
import 'home_tab_setting.dart';

/// Settings → Appearance → Tabs: which tabs the bar shows (only Home can go),
/// their order (same order a long press on the bar edits), Home's own blocks
/// while Home is on, and the tab the app opens on.
class TabsSettingsScreen extends ConsumerWidget {
  const TabsSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    String t(String key) => AppTranslations.translate(context, ref, key);
    final colors = Theme.of(context).colorScheme;
    final homeShown = ref.watch(homeTabShownProvider);
    // Every tab, hidden Home included, so its place can be set while off.
    final all = applyTabOrder(homeShellTabs, ref.watch(shellTabOrderProvider));
    final shown = applyTabOrder(
      ref.watch(shownShellTabsProvider),
      ref.watch(shellTabOrderProvider),
    );
    final start = ref.watch(startTabProvider);

    return Scaffold(
      appBar: AppBar(
        leading: const AppBarBackButton(),
        title: Text(t('settings_tabs')),
      ),
      body: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 24),
        children: [
          PermissionSection(
            divider: false,
            heading: t('settings_tabs_bar'),
            footer: t('settings_tabs_bar_footer'),
            children: [
              ReorderableListView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                buildDefaultDragHandles: false,
                onReorderItem: (from, to) => ref
                    .read(shellTabOrderProvider.notifier)
                    .move(all, from, to),
                children: [
                  for (var i = 0; i < all.length; i++)
                    _TabRow(
                      key: ValueKey(all[i].route),
                      tab: all[i],
                      index: i,
                      label: t(all[i].labelKey),
                      isHome: all[i].route == homeShellTab.route,
                      homeShown: homeShown,
                      alwaysLabel: t('settings_tabs_always'),
                      homeSub: t('settings_tabs_home_sub'),
                    ),
                ],
              ),
            ],
          ),
          if (homeShown) const HomeSectionsSettings(),
          PermissionSection(
            heading: t('settings_start_tab'),
            footer: t('settings_start_tab_sub'),
            children: [
              for (final tab in shown)
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                  leading: ChatIcon(
                    tab.route == start ? tab.selectedIcon : tab.icon,
                    color: tab.route == start
                        ? colors.primary
                        : colors.onSurfaceVariant,
                  ),
                  title: Text(t(tab.labelKey)),
                  trailing: tab.route == start
                      ? ChatIcon(
                          HugeIcons.strokeRoundedTick02,
                          color: colors.primary,
                        )
                      : null,
                  onTap: () =>
                      ref.read(startTabProvider.notifier).choose(tab.route),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TabRow extends ConsumerWidget {
  const _TabRow({
    super.key,
    required this.tab,
    required this.index,
    required this.label,
    required this.isHome,
    required this.homeShown,
    required this.alwaysLabel,
    required this.homeSub,
  });

  final ShellTab tab;
  final int index;
  final String label;
  final bool isHome;
  final bool homeShown;
  final String alwaysLabel;
  final String homeSub;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final on = !isHome || homeShown;
    return Material(
      type: MaterialType.transparency,
      child: ListTile(
        contentPadding: const EdgeInsets.only(left: 20, right: 8),
        leading: ChatIcon(
          tab.icon,
          color: on ? colors.onSurface : colors.onSurfaceVariant,
        ),
        title: Text(label),
        subtitle: Text(isHome ? homeSub : alwaysLabel),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(
              value: on,
              onChanged: isHome
                  ? (v) => ref.read(homeTabShownProvider.notifier).set(v)
                  : null,
            ),
            ReorderableDragStartListener(
              index: index,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: ChatIcon(
                  HugeIcons.strokeRoundedDragDropVertical,
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

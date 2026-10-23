import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/localization/app_translations.dart';
import '../../home/home_sections.dart';
import '../../messages/chat_icon.dart';
import '../../messages/group-member-permissions/permission_section.dart';

/// "Home page" on Settings → Appearance → Tabs: Home's blocks, each with a
/// switch and a drag handle. Shown while Home is in the bar.
class HomeSectionsSettings extends ConsumerWidget {
  const HomeSectionsSettings({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    String t(String key) => AppTranslations.translate(context, ref, key);
    final colors = Theme.of(context).colorScheme;
    final prefs = ref.watch(homeSectionsProvider);
    final sections = prefs.ordered;
    final notifier = ref.read(homeSectionsProvider.notifier);

    return PermissionSection(
      heading: t('settings_home_sections'),
      footer: t('settings_home_sections_footer'),
      children: [
        ReorderableListView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          onReorderItem: notifier.move,
          children: [
            for (var i = 0; i < sections.length; i++)
              Material(
                key: ValueKey(sections[i].id),
                type: MaterialType.transparency,
                child: ListTile(
                  contentPadding: const EdgeInsets.only(left: 20, right: 8),
                  title: Text(t(sections[i].labelKey)),
                  subtitle: sections[i].id == 'nearby'
                      ? Text(t('settings_home_nearby_sub'))
                      : null,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Switch(
                        value: !prefs.hidden.contains(sections[i].id),
                        onChanged: (v) => notifier.setShown(sections[i].id, v),
                      ),
                      ReorderableDragStartListener(
                        index: i,
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
              ),
          ],
        ),
      ],
    );
  }
}

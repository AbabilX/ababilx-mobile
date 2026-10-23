import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/localization/app_translations.dart';
import '../../../shared/widgets/app_bar_back_button.dart';
import '../../profile/providers/profile_provider.dart';
import '../settings-hub/language_dialog.dart';
import '../settings-hub/settings_row.dart';

/// Settings → Appearance: how the app looks. Language, tabs, the launcher
/// icon and the chat wallpaper.
class AppearanceScreen extends ConsumerWidget {
  const AppearanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    String t(String key) => AppTranslations.translate(context, ref, key);
    // valueOrNull, never value: a failed profile load must not throw here.
    final language = ref.watch(
      profileProvider.select((p) => p.valueOrNull?.appLanguage),
    );
    return Scaffold(
      appBar: AppBar(
        leading: const AppBarBackButton(),
        title: Text(t('settings_appearance')),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          SettingsRow(
            icon: HugeIcons.strokeRoundedLanguageSkill,
            title: t('app_language'),
            value: language == null ? null : languageLabel(language),
            onTap: language == null
                ? null
                : () async {
                    final picked = await showLanguageDialog(context, language);
                    if (picked == null) return;
                    await ref
                        .read(profileProvider.notifier)
                        .updateLanguage(picked);
                  },
          ),
          SettingsRow(
            icon: HugeIcons.strokeRoundedDashboardSquare01,
            title: t('settings_tabs'),
            subtitle: t('settings_tabs_sub'),
            onTap: () => context.push('/settings/appearance/tabs'),
          ),
          SettingsRow(
            icon: HugeIcons.strokeRoundedMobileNavigator01,
            title: t('settings_app_icon'),
            subtitle: t('settings_app_icon_sub'),
            onTap: () => context.push('/settings/app-icon'),
          ),
          SettingsRow(
            icon: HugeIcons.strokeRoundedPaintBoard,
            title: t('settings_wallpaper'),
            subtitle: t('settings_wallpaper_sub'),
            onTap: () => context.push('/settings/wallpaper'),
          ),
        ],
      ),
    );
  }
}

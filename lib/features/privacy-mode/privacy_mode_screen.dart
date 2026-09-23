import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/localization/app_translations.dart';
import '../../shared/widgets/app_bar_back_button.dart';
import '../../shared/widgets/app_toast.dart';
import '../messages/chat_icon.dart';
import 'people/privacy_people_row.dart';
import 'privacy_mode_provider.dart';

/// Settings → Privacy mode. One switch and its per-person exceptions, then
/// exactly what it does to the other person, then what it cannot do — a promise that overstates itself
/// is worse than a smaller one kept.
class PrivacyModeScreen extends ConsumerWidget {
  const PrivacyModeScreen({super.key});

  static const _points = [
    (HugeIcons.strokeRoundedKeyboard, 'privacy_mode_point_typing'),
    (HugeIcons.strokeRoundedTick02, 'privacy_mode_point_ticks'),
    (HugeIcons.strokeRoundedShield01, 'privacy_mode_point_status'),
    (HugeIcons.strokeRoundedCall, 'privacy_mode_point_ringing'),
    (HugeIcons.strokeRoundedCallEnd01, 'privacy_mode_point_calls'),
    (HugeIcons.strokeRoundedSmartPhone01, 'privacy_mode_point_screens'),
    (HugeIcons.strokeRoundedTimer02, 'privacy_mode_point_media'),
  ];

  /// What it does for everyone, not only the people you already chat with.
  static const _everyone = [
    (HugeIcons.strokeRoundedSearch01, 'privacy_mode_point_find'),
    (HugeIcons.strokeRoundedUserGroup, 'privacy_mode_point_groups'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    String t(String key) => AppTranslations.translate(context, ref, key);
    return Scaffold(
      appBar: AppBar(
        leading: const AppBarBackButton(),
        title: Text(t('privacy_mode_title')),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          SwitchListTile(
            value: ref.watch(privacyModeProvider),
            onChanged: (on) async {
              final failed = t('privacy_mode_save_failed');
              final ok = await ref.read(privacyModeProvider.notifier).set(on);
              if (!ok && context.mounted) showAppToast(context, failed);
            },
            contentPadding: const EdgeInsets.symmetric(horizontal: 20),
            title: Text(
              t('privacy_mode_title'),
              style: theme.textTheme.titleSmall,
            ),
            subtitle: Text(
              t('privacy_mode_hint'),
              style: theme.textTheme.bodySmall?.copyWith(color: muted),
            ),
          ),
          const PrivacyPeopleRow(),
          const Divider(height: 24),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(
              t('privacy_mode_what'),
              style: theme.textTheme.labelLarge,
            ),
          ),
          for (final (icon, key) in _points)
            ListTile(
              dense: true,
              leading: ChatIcon(icon, size: 20, color: muted),
              title: Text(t(key), style: theme.textTheme.bodyMedium),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: Text(
              t('privacy_mode_everyone'),
              style: theme.textTheme.labelLarge,
            ),
          ),
          for (final (icon, key) in _everyone)
            ListTile(
              dense: true,
              leading: ChatIcon(icon, size: 20, color: muted),
              title: Text(t(key), style: theme.textTheme.bodyMedium),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Text(
              t('privacy_mode_oneway'),
              style: theme.textTheme.bodySmall?.copyWith(color: muted),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Text(
              t('privacy_mode_limits'),
              style: theme.textTheme.bodySmall?.copyWith(color: muted),
            ),
          ),
        ],
      ),
    );
  }
}

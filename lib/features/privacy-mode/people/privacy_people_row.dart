import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/localization/app_translations.dart';
import '../../messages/chat_icon.dart';
import 'privacy_people_provider.dart';

/// "Exceptions" under the privacy switch: how many people have a choice of
/// their own, one tap from the list.
class PrivacyPeopleRow extends ConsumerWidget {
  const PrivacyPeopleRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    String t(String key) => AppTranslations.translate(context, ref, key);
    final count = ref.watch(privacyPeopleProvider.select((m) => m.length));
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      leading: ChatIcon(HugeIcons.strokeRoundedUserGroup, color: muted),
      title: Text(t('privacy_people_title'), style: theme.textTheme.titleSmall),
      subtitle: Text(
        count == 0
            ? t('privacy_people_hint')
            : t('privacy_people_count').replaceAll('{n}', '$count'),
        style: theme.textTheme.bodySmall?.copyWith(color: muted),
      ),
      trailing: ChatIcon(HugeIcons.strokeRoundedArrowRight01, color: muted),
      onTap: () => context.push('/settings/privacy-mode/people'),
    );
  }
}

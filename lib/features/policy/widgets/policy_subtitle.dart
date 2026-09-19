import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_translations.dart';

/// "World-class secured messaging…" with only the first word(s) bold.
class PolicySubtitle extends ConsumerWidget {
  const PolicySubtitle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    String t(String key) => AppTranslations.translate(context, ref, key);
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: t('policy_subtitle_bold'),
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          TextSpan(text: t('policy_subtitle')),
        ],
      ),
      style: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

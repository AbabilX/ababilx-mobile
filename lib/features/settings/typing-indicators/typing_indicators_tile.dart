import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_translations.dart';
import '../../../shared/widgets/app_toast.dart';
import 'typing_indicators_provider.dart';

/// The reference app's switch: off means you neither show nor see "typing…".
class TypingIndicatorsTile extends ConsumerWidget {
  const TypingIndicatorsTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    String t(String key) => AppTranslations.translate(context, ref, key);
    return SwitchListTile(
      value: ref.watch(typingIndicatorsProvider),
      onChanged: (enabled) async {
        final failed = t('typing_indicators_save_failed');
        final ok = await ref
            .read(typingIndicatorsProvider.notifier)
            .set(enabled);
        if (!ok && context.mounted) showAppToast(context, failed);
      },
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      title: Text(
        t('typing_indicators_title'),
        style: theme.textTheme.titleSmall,
      ),
      subtitle: Text(
        t('typing_indicators_hint'),
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

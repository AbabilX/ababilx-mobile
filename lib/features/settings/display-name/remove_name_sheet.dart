import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_translations.dart';
import '../../profile/providers/profile_provider.dart';

/// Confirms removing the account's display name (server migration 0185).
/// Says what others will see instead: the @username, or "AbabilX user" for
/// an account without one. Resolves true when confirmed.
Future<bool?> showRemoveNameSheet(BuildContext context, WidgetRef ref) {
  String t(String key) => AppTranslations.translate(context, ref, key);
  final handle = ref.read(profileProvider).valueOrNull?.username.trim() ?? '';
  final body = handle.isEmpty
      ? t('edit_name_remove_body_nameless')
      : t('edit_name_remove_body').replaceAll('{username}', '@$handle');
  return showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    builder: (sheet) {
      final theme = Theme.of(sheet);
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                t('edit_name_remove_title'),
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                body,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.error,
                  foregroundColor: theme.colorScheme.onError,
                ),
                onPressed: () => Navigator.pop(sheet, true),
                child: Text(t('edit_name_remove')),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(sheet, false),
                child: Text(t('cancel')),
              ),
            ],
          ),
        ),
      );
    },
  );
}

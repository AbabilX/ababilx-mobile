import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/localization/app_translations.dart';
import '../chat_icon.dart';

/// A folder with no chat in it yet, and the way to add some.
class FolderEmpty extends ConsumerWidget {
  const FolderEmpty({super.key, required this.name, this.onAdd});

  final String name;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    String t(String key) => AppTranslations.translate(context, ref, key);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ChatIcon(
              HugeIcons.strokeRoundedFolder01,
              size: 40,
              color: colors.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              name,
              textAlign: TextAlign.center,
              style: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              t('chat_folder_empty'),
              textAlign: TextAlign.center,
              style: text.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: onAdd,
              child: Text(t('chat_folder_add_chats')),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_translations.dart';

class ConversationListEmpty extends ConsumerWidget {
  const ConversationListEmpty({super.key, required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.chat_bubble_outline_rounded,
              size: 46,
              color: colors.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              AppTranslations.translate(context, ref, 'chat_empty_title'),
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              AppTranslations.translate(context, ref, 'chat_empty_body'),
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onStart,
              icon: const Icon(Icons.edit_outlined),
              label: Text(
                AppTranslations.translate(context, ref, 'chat_new_message'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

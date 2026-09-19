import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_translations.dart';

Future<bool> confirmRemoveConnection(
  BuildContext context,
  WidgetRef ref, {
  required String name,
}) async {
  final colors = Theme.of(context).colorScheme;
  final body = AppTranslations.translate(
    context,
    ref,
    'chat_remove_connection_confirm',
  ).replaceFirst('{name}', name);
  final ok = await showDialog<bool>(
    context: context,
    builder: (dialog) => AlertDialog(
      title: Text(AppTranslations.translate(context, ref, 'chat_remove')),
      content: Text(body, style: const TextStyle(height: 1.4)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialog, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: colors.error),
          onPressed: () => Navigator.pop(dialog, true),
          child: Text(AppTranslations.translate(context, ref, 'chat_remove')),
        ),
      ],
    ),
  );
  return ok == true;
}

Future<bool> confirmBlockConnection(
  BuildContext context,
  WidgetRef ref, {
  required String name,
}) async {
  final colors = Theme.of(context).colorScheme;
  final title = AppTranslations.translate(
    context,
    ref,
    'chat_block_connection_title',
  ).replaceFirst('{name}', name);
  final body = AppTranslations.translate(
    context,
    ref,
    'chat_block_connection_confirm',
  );
  final ok = await showDialog<bool>(
    context: context,
    builder: (dialog) => AlertDialog(
      title: Text(title),
      content: Text(body, style: const TextStyle(height: 1.4)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialog, false),
          child: Text(AppTranslations.translate(context, ref, 'cancel')),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: colors.error),
          onPressed: () => Navigator.pop(dialog, true),
          child: Text(AppTranslations.translate(context, ref, 'chat_block')),
        ),
      ],
    ),
  );
  return ok == true;
}

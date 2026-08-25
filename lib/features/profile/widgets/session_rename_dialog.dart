import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_translations.dart';

/// Matches maxSessionNameLen on the backend, which rejects anything longer.
const int kMaxSessionNameLength = 48;

/// Asks for a device name. Returns the new name, or null when cancelled —
/// an empty string is a real answer: it clears the override so the automatic
/// "Chrome on macOS" style label comes back.
Future<String?> showSessionRenameDialog(
  BuildContext context,
  WidgetRef ref, {
  required String currentLabel,
}) {
  final controller = TextEditingController(text: currentLabel);

  return showDialog<String>(
    context: context,
    builder: (dialogCtx) {
      final colors = Theme.of(dialogCtx).colorScheme;
      return AlertDialog(
        backgroundColor: colors.surfaceContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: colors.outline),
        ),
        title: Text(
          AppTranslations.translate(dialogCtx, ref, 'devices_rename'),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: controller,
              autofocus: true,
              maxLength: kMaxSessionNameLength,
              textInputAction: TextInputAction.done,
              onSubmitted: (v) => Navigator.pop(dialogCtx, v),
              decoration: InputDecoration(
                hintText: AppTranslations.translate(
                  dialogCtx,
                  ref,
                  'devices_rename_hint',
                ),
                border: const OutlineInputBorder(),
              ),
            ),
            Text(
              AppTranslations.translate(dialogCtx, ref, 'devices_rename_help'),
              style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text(AppTranslations.translate(dialogCtx, ref, 'cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogCtx, controller.text),
            child: Text(
              AppTranslations.translate(dialogCtx, ref, 'devices_save'),
            ),
          ),
        ],
      );
    },
  ).whenComplete(controller.dispose);
}

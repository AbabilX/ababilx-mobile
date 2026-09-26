import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/localization/app_translations.dart';
import '../chat_icon.dart';

/// The warning before "Unpin all": a bottom sheet, like the app's other
/// confirmations, with the destructive choice in red. Answers true only when
/// the red button was pressed — a swipe down or Cancel keeps every pin.
Future<bool> confirmUnpinAll(
  BuildContext context,
  WidgetRef ref,
  int count,
) async {
  String tr(String key) => AppTranslations.translate(context, ref, key);
  final go = await showModalBottomSheet<bool>(
    context: context,
    useRootNavigator: true,
    showDragHandle: true,
    builder: (sheet) {
      final colors = Theme.of(sheet).colorScheme;
      final text = Theme.of(sheet).textTheme;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                tr('chat_unpin_all_confirm').replaceAll('{count}', '$count'),
                style: text.titleLarge,
              ),
              const SizedBox(height: 6),
              Text(
                tr('chat_unpin_all_body'),
                style: text.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: colors.error,
                  foregroundColor: colors.onError,
                  minimumSize: const Size.fromHeight(48),
                ),
                onPressed: () => Navigator.of(sheet).pop(true),
                icon: ChatIcon(
                  HugeIcons.strokeRoundedPinOff,
                  size: 20,
                  color: colors.onError,
                ),
                label: Text(tr('chat_unpin_all')),
              ),
              const SizedBox(height: 8),
              TextButton(
                style: TextButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                onPressed: () => Navigator.of(sheet).pop(false),
                child: Text(tr('cancel')),
              ),
            ],
          ),
        ),
      );
    },
  );
  return go == true;
}

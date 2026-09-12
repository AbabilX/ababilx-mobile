import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_translations.dart';

/// Signal's `ActionModeTopBar`: a close X where the back arrow was, and the
/// count where the conversation's name was. It replaces the chat header rather
/// than sitting over it, so the two can never both be on screen.
class SelectionTopBar extends ConsumerWidget {
  const SelectionTopBar({
    super.key,
    required this.count,
    required this.onClose,
  });

  final int count;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final surface =
        theme.appBarTheme.backgroundColor ?? theme.colorScheme.surface;
    final label = AppTranslations.translate(context, ref, 'chat_selected');

    return Material(
      color: surface,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: kToolbarHeight,
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.close),
                tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                onPressed: onClose,
              ),
              Expanded(
                child: Text(
                  '$count $label',
                  style: theme.textTheme.titleLarge,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }
}

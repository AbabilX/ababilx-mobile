import 'package:flutter/material.dart';

import '../data/models/chat_models.dart';
import 'composer_attach.dart';

class ComposerExpandedShell extends StatelessWidget {
  const ComposerExpandedShell({
    super.key,
    required this.pending,
    required this.onRemove,
    required this.field,
    required this.toolbar,
  });

  final List<ChatAttachmentInput> pending;
  final ValueChanged<int> onRemove;
  final Widget field;
  final Widget toolbar;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surfaceContainerLow,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 4, 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (pending.isNotEmpty)
                ComposerPendingChips(items: pending, onRemove: onRemove),
              field,
              toolbar,
            ],
          ),
        ),
      ),
    );
  }
}

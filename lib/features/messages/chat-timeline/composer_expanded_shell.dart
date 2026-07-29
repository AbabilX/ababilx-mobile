import 'package:flutter/material.dart';

import '../data/models/chat_models.dart';
import 'composer_attach.dart';

class ComposerExpandedShell extends StatelessWidget {
  const ComposerExpandedShell({
    super.key,
    required this.pending,
    required this.onRemove,
    required this.onAddPhoto,
    required this.field,
    this.replyBanner,
  });

  final List<ChatAttachmentInput> pending;
  final ValueChanged<int> onRemove;
  final VoidCallback onAddPhoto;
  final Widget field;
  final Widget? replyBanner;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      clipBehavior: Clip.antiAlias,
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (replyBanner case final banner?) banner,
            if (pending.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                child: ComposerPendingPreviews(
                  items: pending,
                  onRemove: onRemove,
                  onAddPhoto: onAddPhoto,
                ),
              ),
            field,
          ],
        ),
      ),
    );
  }
}

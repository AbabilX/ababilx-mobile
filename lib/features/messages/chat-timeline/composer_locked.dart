import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_translations.dart';

class ComposerLocked extends ConsumerWidget {
  const ComposerLocked({
    super.key,
    this.messageKey = 'chat_connection_required',
  });

  /// Which locked copy to show. The default is the blocked-DM case; a webhook
  /// feed is locked for everyone by design, so telling its readers they
  /// "cannot send messages in this chat" reads as a fault rather than as the
  /// point of the room.
  final String messageKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        color: colors.surfaceContainerLow,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline_rounded, color: colors.onSurfaceVariant),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                AppTranslations.translate(context, ref, messageKey),
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

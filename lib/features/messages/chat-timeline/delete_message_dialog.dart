import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_translations.dart';

/// Who a delete removes the message for.
enum MessageDeleteScope { everyone, me }

/// WhatsApp's delete prompt. "Delete for me" is always offered — it only ever
/// touches this account. "Delete for everyone" only when every message is the
/// caller's own, because the server refuses anybody else's row.
Future<MessageDeleteScope?> showDeleteMessageDialog(
  BuildContext context,
  WidgetRef ref, {
  required int count,
  required bool canDeleteForEveryone,
}) {
  String tr(String key) => AppTranslations.translate(context, ref, key);
  final title = count == 1
      ? tr('chat_delete_message_title')
      : tr('chat_delete_selected_title');
  final colors = Theme.of(context).colorScheme;
  return showDialog<MessageDeleteScope>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(
        canDeleteForEveryone
            ? tr('chat_delete_scope_hint')
            : tr('chat_delete_for_me_hint'),
      ),
      actionsOverflowDirection: VerticalDirection.down,
      actionsOverflowButtonSpacing: 4,
      actions: [
        if (canDeleteForEveryone)
          TextButton(
            style: TextButton.styleFrom(foregroundColor: colors.error),
            onPressed: () => Navigator.pop(ctx, MessageDeleteScope.everyone),
            child: Text(tr('chat_delete_for_everyone')),
          ),
        TextButton(
          style: TextButton.styleFrom(foregroundColor: colors.error),
          onPressed: () => Navigator.pop(ctx, MessageDeleteScope.me),
          child: Text(tr('chat_delete_for_me')),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(tr('cancel')),
        ),
      ],
    ),
  );
}

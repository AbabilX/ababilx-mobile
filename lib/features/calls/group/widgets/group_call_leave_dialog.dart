import 'package:flutter/material.dart';

import '../../../../core/localization/app_translations.dart';

/// Confirm before hanging up — mirrors web `call-guard/call-leave-dialog.tsx`.
///
/// Returns true when the user chose to leave.
Future<bool> confirmLeaveGroupCall(
  BuildContext context, {
  String lang = 'en',
}) async {
  String tr(String key) => AppTranslations.of(lang, key);
  final colors = Theme.of(context).colorScheme;
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(tr('group_leave_title')),
      content: Text(tr('group_leave_body')),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(tr('group_stay')),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: colors.error,
            foregroundColor: colors.onError,
          ),
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(tr('group_confirm_leave')),
        ),
      ],
    ),
  );
  return result ?? false;
}

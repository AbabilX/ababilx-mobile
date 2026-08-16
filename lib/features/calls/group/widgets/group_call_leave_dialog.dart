import 'package:flutter/material.dart';

/// Confirm before hanging up — mirrors web `call-guard/call-leave-dialog.tsx`.
///
/// Returns true when the user chose to leave.
Future<bool> confirmLeaveGroupCall(BuildContext context) async {
  final colors = Theme.of(context).colorScheme;
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Leave this call?'),
      content: const Text('You will disconnect from everyone in this call.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Stay'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: colors.error,
            foregroundColor: colors.onError,
          ),
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Leave'),
        ),
      ],
    ),
  );
  return result ?? false;
}

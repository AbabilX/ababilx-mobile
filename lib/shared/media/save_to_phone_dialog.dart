import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _dismissKey = 'ababilx_save_to_phone_warning_dismissed';

Future<bool> _isWarningDismissed() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_dismissKey) ?? false;
}

Future<void> _dismissWarningForever() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_dismissKey, true);
}

/// The reference app's save confirmation, one for one.
///
/// The point is not the tap — it is telling the user that a file leaving the
/// app's sandbox stops being private to it. Once they have read that, the
/// checkbox retires the dialog for good, so saving stays a single tap.
Future<bool> confirmSaveToPhone(
  BuildContext context, {
  required int fileCount,
}) async {
  if (await _isWarningDismissed()) return true;
  if (!context.mounted) return false;

  var dontAskAgain = false;
  final accepted = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: const Text('Save to phone?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              fileCount > 1
                  ? 'These $fileCount files will be saved to your phone\'s '
                        'storage. Other apps may be able to access them '
                        'depending on your phone\'s permissions.'
                  : 'This media will be saved to your phone\'s storage. Other '
                        'apps may be able to access it depending on your '
                        'phone\'s permissions.',
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: CheckboxListTile(
                value: dontAskAgain,
                onChanged: (v) => setState(() => dontAskAgain = v ?? false),
                title: const Text('Don\'t show this again'),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save'),
          ),
        ],
      ),
    ),
  );

  if (accepted == true && dontAskAgain) await _dismissWarningForever();
  return accepted ?? false;
}

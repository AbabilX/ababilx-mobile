import 'package:flutter/material.dart';

import 'save_to_phone.dart';
import 'save_to_phone_dialog.dart';

/// The whole user-facing save: warn once, copy, then say what happened.
///
/// Signal's shape — confirmation dialog, then a single result message for the
/// batch rather than one per file, so saving an album is one interaction.
/// Returns whether anything was written, for callers that show their own
/// state; the message is shown either way.
Future<bool> saveToPhoneWithFeedback(
  BuildContext context,
  List<SaveToPhoneRequest> files,
) async {
  if (files.isEmpty) {
    _say(context, 'Nothing to save');
    return false;
  }
  if (!await confirmSaveToPhone(context, fileCount: files.length)) return false;
  if (!context.mounted) return false;
  return saveConfirmedToPhone(context, files);
}

/// The half after the dialog. Callers that have to fetch bytes first ask for
/// consent *before* the wait and then come here, so the user is never left
/// staring at a stalled screen wondering whether their tap registered.
Future<bool> saveConfirmedToPhone(
  BuildContext context,
  List<SaveToPhoneRequest> files, {
  int expected = 0,
}) async {
  final total = expected > files.length ? expected : files.length;
  if (files.isEmpty) {
    _say(context, _message(saved: 0, total: total));
    return false;
  }
  final results = <SaveToPhoneResult>[];
  for (final file in files) {
    results.add(await saveFileToPhone(file));
  }
  if (!context.mounted) return results.any((r) => r.ok);

  final saved = results.where((r) => r.ok).length;
  _say(context, _message(saved: saved, total: total));
  return saved > 0;
}

/// Single-file convenience — the fullscreen viewers' Save button.
Future<bool> saveOneToPhone(
  BuildContext context, {
  required String localPath,
  required String fileName,
  String contentType = '',
}) {
  return saveToPhoneWithFeedback(context, [
    SaveToPhoneRequest(
      sourcePath: localPath,
      fileName: fileName,
      contentType: contentType,
    ),
  ]);
}

String _message({required int saved, required int total}) {
  if (saved == 0) {
    return total > 1 ? 'Couldn\'t save these files' : 'Couldn\'t save the file';
  }
  if (saved < total) return 'Saved $saved of $total to $saveToPhoneFolderLabel';
  return total > 1
      ? 'Saved $total files to $saveToPhoneFolderLabel'
      : 'Saved to $saveToPhoneFolderLabel';
}

void _say(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message), duration: const Duration(seconds: 3)),
  );
}

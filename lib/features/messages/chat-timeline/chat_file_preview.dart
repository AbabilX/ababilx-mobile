import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';

import '../data/models/chat_models.dart';

Future<void> openChatAttachment(
  BuildContext context,
  ChatMessageAttachment file, {
  required String localPath,
}) async {
  if (file.locked || localPath.isEmpty) {
    _toast(context, 'This file is not available');
    return;
  }
  final result = await OpenFilex.open(localPath, type: file.contentType);
  if (result.type != ResultType.done && context.mounted) {
    _toast(
      context,
      result.message.isEmpty ? 'Could not open file' : result.message,
    );
  }
}

void _toast(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

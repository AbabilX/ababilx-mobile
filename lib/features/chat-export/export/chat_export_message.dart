import 'dart:io';

import '../../../shared/text/display_name.dart';
import '../../messages/data/models/chat_attachment.dart';
import '../../messages/data/models/chat_message.dart';
import '../../messages/tiptap_plain_text.dart';
import '../format/chat_export_format.dart';

/// What is on the phone for an attachment: the file, and the name the
/// store kept (an encrypted upload's row says only `file`).
typedef ExportLocalFile = Future<(File, String)?> Function(String fileUrl);

/// The server's placeholder names for an encrypted file; never shown.
const _sealedNames = {'file', 'voice-message', ''};

/// A file's real name: the attachment's, else the store's, else the name on
/// disk, which keeps the extension a viewer needs.
String exportFileName(ChatMessageAttachment a, String stored, File? file) {
  if (!_sealedNames.contains(a.fileName)) return a.fileName;
  if (!_sealedNames.contains(stored)) return stored;
  if (file != null) return file.uri.pathSegments.last;
  return a.fileName.isEmpty ? 'file' : a.fileName;
}

/// Turns a stored row into its export form. [text] is the opened body (null
/// when this phone could not open it); [sender] the name to print.
ExportedMessage exportedMessage(
  ChatMessage m, {
  required String? text,
  required String sender,
  required List<ExportedFile> files,
}) {
  final plain = tiptapToPlainText(text ?? '');
  final body = switch (m.messageType) {
    _ when m.isEncrypted && text == null =>
      '[message could not be opened on this phone]',
    'voice_call' when plain.isEmpty => '[voice call]',
    'group_call' when plain.isEmpty => '[group call]',
    _ => plain,
  };
  final quote = m.quote;
  return ExportedMessage(
    id: m.id,
    at: m.createdAt,
    senderId: m.userId,
    sender: sender,
    kind: m.messageType.isEmpty ? 'text' : m.messageType,
    text: body,
    edited: m.editedAt != null,
    forwardedFrom: m.forwardedFromName,
    replyTo: quote == null
        ? null
        : ExportedReply(
            id: quote.messageId,
            sender: safeDisplayName(
              quote.userName,
              fallback: namelessUserLabel,
            ),
            text: quote.isEncrypted || quote.deleted
                ? null
                : tiptapToPlainText(quote.body),
          ),
    files: files,
  );
}

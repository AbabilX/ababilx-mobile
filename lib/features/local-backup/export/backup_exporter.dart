import 'dart:io';

import '../../messages/data/local/chat_message_row.dart';
import '../../messages/data/models/chat_conversation.dart';
import '../../messages/data/models/chat_conversation_json.dart';
import '../../messages/data/models/chat_message.dart';
import '../data/backup_choices.dart';
import '../format/backup_errors.dart';
import '../format/backup_file_writer.dart';
import 'backup_selection.dart';

class BackupExportStats {
  const BackupExportStats({
    required this.messages,
    required this.files,
    required this.unreadable,
  });

  final int messages;
  final int files;

  /// Sealed messages this phone could not open. Kept as ciphertext — a
  /// recovery code restored later may still open them — but carried without
  /// text, so a restore after "start fresh" cannot bring them back.
  final int unreadable;
}

/// Streams this phone's history into a [BackupFileWriter].
///
/// Frames: `conv` for each chat that is backed up, then `msg` oldest first —
/// the stored JSON exactly (ciphertext and all, body blank when sealed) plus
/// `p`, the readable text, when there is one — each followed by a `file` for
/// every attachment whose bytes go in. The stored row is kept whole on
/// purpose: restored, it is the same row the server serves, so the next page
/// from the server replaces nothing, and a phone whose key still opens it
/// needs the text from nowhere else.
class BackupExporter {
  BackupExporter({
    required this.readPage,
    required this.allows,
    required this.openBody,
    required this.localFile,
    required this.choices,
    required this.conversations,
  });

  /// One ascending page of the local archive (`ChatMessageStore.exportPage`).
  final Future<List<ChatMessage>> Function(int? afterMs, String? afterId)
  readPage;

  /// The deletion filter: a deleted chat must not come back from a backup.
  final bool Function(ChatMessage message) allows;

  /// The readable text, or null when this phone cannot open it.
  final Future<String?> Function(ChatMessage message) openBody;

  /// The downloaded file for an attachment URL, or null when not on disk.
  final Future<File?> Function(String fileUrl) localFile;

  final BackupChoices choices;
  final Map<String, ChatConversation> conversations;

  Future<BackupExportStats> run(
    BackupFileWriter writer, {
    void Function(int messages)? onProgress,
    bool Function()? shouldContinue,
  }) async {
    for (final conversation in conversations.values) {
      if (!conversationIncluded(conversation, choices)) continue;
      await writer.addFrame({'t': 'conv', 'c': conversation.toJson()});
    }
    final written = <String>{};
    var messages = 0;
    var files = 0;
    var unreadable = 0;
    int? afterMs;
    String? afterId;
    while (true) {
      if (shouldContinue?.call() == false) throw const BackupCancelledError();
      final page = await readPage(afterMs, afterId);
      if (page.isEmpty) break;
      for (final message in page) {
        if (!allows(message) || !messageIncluded(message)) continue;
        final conversation = conversations[message.conversationId];
        if (!conversationIncluded(conversation, choices)) continue;
        final stored = message.toJson();
        String? text;
        if (message.isEncrypted) {
          stored['body'] = '';
          text = await openBody(message);
          if (text == null) unreadable++;
        }
        await writer.addFrame({'t': 'msg', 'm': stored, 'p': ?text});
        messages++;
        for (final a in message.attachments) {
          if (!attachmentBytesIncluded(a, choices) || !written.add(a.fileUrl)) {
            continue;
          }
          final file = await localFile(a.fileUrl);
          if (file == null) continue;
          final added = await writer.addFile({
            'u': a.fileUrl,
            'n': a.fileName,
            'ct': a.contentType,
          }, file);
          if (added) files++;
        }
      }
      onProgress?.call(messages);
      // The store's own cursor (time, row id), as the archive exporter reads
      // it, so two messages in one millisecond still have a successor.
      afterMs = messageTimeMs(page.last);
      afterId = localMessageRowId(page.last);
    }
    return BackupExportStats(
      messages: messages,
      files: files,
      unreadable: unreadable,
    );
  }
}

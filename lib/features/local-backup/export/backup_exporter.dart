import 'dart:io';

import '../../messages/data/local/chat_message_row.dart';
import '../../messages/data/models/chat_conversation.dart';
import '../../messages/data/models/chat_conversation_json.dart';
import '../../messages/data/models/chat_message.dart';
import '../auto/backup_media_store.dart';
import '../auto/backup_message_segments.dart';
import '../data/backup_choices.dart';
import '../format/backup_errors.dart';
import '../format/backup_file_writer.dart';
import 'backup_segment_export.dart';
import 'backup_selection.dart';
import 'backup_yield.dart';

/// `(done, total)`; a total of 0 means still counting.
typedef BackupProgress = void Function(int done, int total);

class BackupExportStats {
  const BackupExportStats({
    required this.messages,
    required this.files,
    required this.unreadable,
    int? sealed,
    this.timing = '',
  }) : sealed = sealed ?? messages;

  /// Messages the backup holds.
  final int messages;
  final int files;

  /// Sealed messages this phone could not open. Kept as ciphertext — a
  /// recovery code restored later may still open them — but carried without
  /// text, so a restore after "start fresh" cannot bring them back.
  final int unreadable;

  /// Messages this run actually wrote. Less than [messages] when weeks an
  /// earlier run sealed were kept as they were (automatic folder).
  final int sealed;

  /// Where the run's time went, for the log line.
  final String timing;
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
///
/// With [segments] (the automatic folder) the `msg` frames go into sealed
/// weeks instead, written only when the week changed, and the main file
/// lists them (`seg`) — see [BackupMessageSegments].
class BackupExporter {
  BackupExporter({
    required this.readPage,
    required this.allows,
    required this.openBody,
    required this.localFile,
    required this.choices,
    required this.conversations,
    this.media,
    this.segments,
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

  /// Set by the automatic backup: attachment bytes go here, one file each,
  /// instead of into [BackupFileWriter]. Asked about every included
  /// attachment, on the phone or not, so it knows what is still wanted.
  final BackupMediaSink? media;

  /// Set by the automatic backup: messages go into sealed weeks.
  final BackupMessageSegments? segments;

  Future<BackupExportStats> run(
    BackupFileWriter writer, {
    BackupProgress? onProgress,
    bool Function()? shouldContinue,
  }) async {
    for (final conversation in conversations.values) {
      if (!conversationIncluded(conversation, choices)) continue;
      await writer.addFrame({'t': 'conv', 'c': conversation.toJson()});
    }
    final weeks = segments;
    if (weeks != null) {
      return BackupSegmentExport(
        this,
        weeks,
      ).run(writer, onProgress: onProgress, shouldContinue: shouldContinue);
    }
    final seen = <String>{};
    final turn = BackupYield();
    var messages = 0;
    var files = 0;
    var unreadable = 0;
    int? afterMs;
    String? afterId;
    while (true) {
      if (shouldContinue?.call() == false) throw const BackupCancelledError();
      final page = await readPage(afterMs, afterId);
      if (page.isEmpty) break;
      final included = page.where(includes).toList();
      // Opened side by side, as the automatic backup does (its comment says
      // why), then written in order.
      final texts = await Future.wait(
        included.map((m) => m.isEncrypted ? openBody(m) : Future.value(null)),
      );
      for (var i = 0; i < included.length; i++) {
        await turn.maybe();
        final message = included[i];
        final text = texts[i];
        if (message.isEncrypted && text == null) unreadable++;
        await writer.addFrame({
          't': 'msg',
          'm': storedRow(message),
          'p': ?text,
        });
        messages++;
        files += await addFiles(message, seen, writer);
      }
      onProgress?.call(messages, 0);
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

  /// Whether [message] goes into the backup at all.
  bool includes(ChatMessage message) =>
      allows(message) &&
      messageIncluded(message) &&
      conversationIncluded(conversations[message.conversationId], choices);

  /// The row as stored, its body blank when sealed (the text travels as `p`).
  Map<String, dynamic> storedRow(ChatMessage message) {
    final stored = message.toJson();
    if (message.isEncrypted) stored['body'] = '';
    return stored;
  }

  /// Puts [message]'s attachments where they go; returns how many are in the
  /// backup. [seen] keeps a file shared by several messages to one copy.
  Future<int> addFiles(
    ChatMessage message,
    Set<String> seen,
    BackupFileWriter writer,
  ) async {
    var files = 0;
    for (final a in message.attachments) {
      if (!attachmentBytesIncluded(a, choices) || !seen.add(a.fileUrl)) {
        continue;
      }
      final sink = media;
      if (sink != null && await sink.holds(a.fileUrl)) {
        files++;
        continue;
      }
      final file = await localFile(a.fileUrl);
      if (file == null) continue;
      final frame = {'u': a.fileUrl, 'n': a.fileName, 'ct': a.contentType};
      final added = sink != null
          ? await sink.put(frame, file)
          : await writer.addFile(frame, file);
      if (added) files++;
    }
    return files;
  }
}

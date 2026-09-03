import 'dart:io';
import 'dart:typed_data';

import '../../../shared/media/picked_media_file.dart';
import '../../attachments/services/attachment_adopter.dart';
import '../../messages/data/models/chat_models.dart';
import '../../messages/providers/chat_provider.dart';
import '../data/share_intake_channel.dart';
import '../data/shared_payload.dart';

/// How a share landed. Reported per conversation so the UI can be honest about
/// a partial send instead of claiming success for all of them.
class ShareSendResult {
  const ShareSendResult({
    required this.sent,
    required this.failed,
    this.skippedFiles = 0,
  });

  final int sent;
  final List<String> failed;

  /// Files that could not be read, or turned out to be over the cap once
  /// copied — a provider is free to report no size at all beforehand.
  final int skippedFiles;

  bool get allSent => failed.isEmpty;
  bool get noneSent => sent == 0;
}

/// One shared file, now actually on disk.
class _Materialized {
  const _Materialized(this.file, this.bytes, this.temp);

  final SharedFile file;
  final Uint8List bytes;
  final File temp;
}

/// Copies the shared files out of their content providers, uploads them, and
/// posts one message per selected conversation.
///
/// Each conversation gets its own upload — attachments are presigned against a
/// conversation, and a personal chat and a workspace chat do not even store
/// into the same bucket path — but the copy out of the provider happens once.
/// The cache copies are deleted before returning, whatever happened.
///
/// A conversation that fails is recorded and the loop continues: one dead
/// upload should not swallow the other recipients.
Future<ShareSendResult> sendSharedPayload({
  required ChatNotifier chat,
  required ShareIntakeChannel channel,
  required SharedPayload payload,
  required String body,
  required List<String> conversationIds,
  AttachmentAdopter? adopter,
}) async {
  final ready = <_Materialized>[];
  var skipped = 0;
  try {
    for (final file in payload.sendableFiles) {
      final materialized = await _materialize(channel, file);
      if (materialized == null) {
        skipped++;
        continue;
      }
      ready.add(materialized);
    }
    skipped += payload.oversizedCount;

    var sent = 0;
    final failed = <String>[];
    for (final convId in conversationIds) {
      try {
        final attachments = await _uploadInto(chat, convId, ready, adopter);
        final message = await chat.sendMessage(
          conversationId: convId,
          body: body,
          attachments: attachments,
        );
        if (message == null) {
          await _discardAll(chat, convId, attachments);
          failed.add(convId);
          continue;
        }
        sent++;
      } catch (_) {
        failed.add(convId);
      }
    }
    return ShareSendResult(sent: sent, failed: failed, skippedFiles: skipped);
  } finally {
    for (final item in ready) {
      try {
        if (item.temp.existsSync()) item.temp.deleteSync();
      } catch (_) {
        // The OS reclaims cacheDir; a stuck temp file is not worth an error.
      }
    }
  }
}

Future<_Materialized?> _materialize(
  ShareIntakeChannel channel,
  SharedFile file,
) async {
  final path = await channel.materialize(file.uri, file.fileName);
  if (path == null || path.isEmpty) return null;
  final temp = File(path);
  try {
    final bytes = await temp.readAsBytes();
    // A provider may report no size up front, so the cap is enforced here too
    // — this is the first point where the real length is known.
    if (bytes.isEmpty || bytes.length > maxWorkspaceAttachmentBytes) {
      await temp.delete();
      return null;
    }
    return _Materialized(file, bytes, temp);
  } catch (_) {
    try {
      if (temp.existsSync()) temp.deleteSync();
    } catch (_) {}
    return null;
  }
}

Future<List<ChatAttachmentInput>> _uploadInto(
  ChatNotifier chat,
  String conversationId,
  List<_Materialized> items,
  AttachmentAdopter? adopter,
) async {
  final uploaded = <ChatAttachmentInput>[];
  for (final item in items) {
    final presign = await chat.presignAttachment(
      conversationId,
      contentType: item.file.contentType,
      fileName: item.file.fileName,
      sizeBytes: item.bytes.length,
    );
    try {
      await chat.uploadAttachmentBytes(
        presign,
        item.bytes,
        item.file.contentType,
      );
      // The shared file is already on this device — file it under the URL it
      // landed at so the sender never sees a download badge for it.
      await adopter?.adoptFile(
        fileUrl: presign.publicUrl,
        fileName: item.file.fileName,
        contentType: item.file.contentType,
        source: item.temp,
      );
    } catch (_) {
      // Release the reservation before giving up, or the user's storage quota
      // slowly fills with objects no message ever referenced.
      await _discard(chat, conversationId, presign.publicUrl);
      await _discardAll(chat, conversationId, uploaded);
      rethrow;
    }
    uploaded.add(
      ChatAttachmentInput(
        fileUrl: presign.publicUrl,
        fileName: item.file.fileName,
        contentType: item.file.contentType,
        sizeBytes: item.bytes.length,
      ),
    );
  }
  return uploaded;
}

Future<void> _discardAll(
  ChatNotifier chat,
  String conversationId,
  List<ChatAttachmentInput> attachments,
) async {
  for (final a in attachments) {
    await _discard(chat, conversationId, a.fileUrl);
  }
}

Future<void> _discard(
  ChatNotifier chat,
  String conversationId,
  String fileUrl,
) async {
  try {
    await chat.discardUpload(conversationId, fileUrl);
  } catch (_) {
    // Best effort — the sweeper cleans orphans, and failing here would mask
    // the real error the caller is already handling.
  }
}

import '../../attachments/services/attachment_adopter.dart';
import '../chat-recipient-picker/chat_recipient_target.dart';
import '../data/models/chat_models.dart';
import '../providers/chat_provider.dart';
import 'camera_capture.dart';

/// How a camera send landed, per chat, so a partial send is never reported as
/// a whole one.
class CameraSendResult {
  const CameraSendResult({required this.sent, required this.total});

  final int sent;
  final int total;

  bool get allSent => sent == total;
  bool get noneSent => sent == 0;
}

/// Turns picked destinations into conversation ids, opening a DM for a person
/// who has none yet. Two picks that lead to the same chat count once.
Future<List<String>> resolveCameraTargets(
  ChatNotifier notifier,
  List<ChatConversation> dms,
  List<ChatRecipientTarget> targets,
) async {
  final ids = <String>{};
  for (final target in targets) {
    if (target.kind == ChatRecipientKind.conversation) {
      ids.add(target.id);
      continue;
    }
    final existing = dms.where((dm) => dm.peerUserId == target.id);
    ids.add(
      existing.isNotEmpty
          ? existing.first.id
          : (await notifier.startDm(target.id)).id,
    );
  }
  return ids.toList();
}

/// Posts the capture to every chat as one message each.
///
/// Each chat gets its own upload: a file is presigned against a conversation
/// and sealed under that conversation's key. A chat that fails is counted and
/// the rest still go out.
Future<CameraSendResult> sendCameraCapture({
  required ChatNotifier notifier,
  required AttachmentAdopter adopter,
  required ChatCameraCapture capture,
  required List<String> conversationIds,
}) async {
  var sent = 0;
  for (final conversationId in conversationIds) {
    try {
      await _uploadAndSend(notifier, adopter, conversationId, capture);
      sent++;
    } catch (_) {
      // Counted by its absence from `sent`.
    }
  }
  return CameraSendResult(sent: sent, total: conversationIds.length);
}

/// One message carrying everything the camera flow produced. A failed upload
/// or a refused send gives back the objects it reserved, so an abandoned send
/// is not charged to the conversation's storage.
Future<void> _uploadAndSend(
  ChatNotifier notifier,
  AttachmentAdopter adopter,
  String conversationId,
  ChatCameraCapture capture,
) async {
  final attachments = <ChatAttachmentInput>[];
  final reserved = <String>[];
  try {
    for (final picked in capture.files) {
      final presign = await notifier.presignAttachment(
        conversationId,
        contentType: picked.contentType,
        fileName: picked.fileName,
        sizeBytes: picked.sizeBytes,
      );
      reserved.add(presign.publicUrl);
      await notifier.uploadAttachmentBytes(
        presign,
        picked.bytes,
        picked.contentType,
      );
      await adopter.adoptBytes(
        fileUrl: presign.publicUrl,
        fileName: picked.fileName,
        contentType: picked.contentType,
        bytes: picked.bytes,
      );
      attachments.add(
        ChatAttachmentInput(
          fileUrl: presign.publicUrl,
          fileName: picked.fileName,
          contentType: picked.contentType,
          sizeBytes: picked.sizeBytes,
        ),
      );
    }
    final message = await notifier.sendMessage(
      conversationId: conversationId,
      body: capture.caption,
      attachments: attachments,
    );
    if (message == null) throw StateError('send refused');
  } catch (_) {
    for (final url in reserved) {
      try {
        await notifier.discardUpload(conversationId, url);
      } catch (_) {
        // Best effort; the real error is the one being rethrown.
      }
    }
    rethrow;
  }
}

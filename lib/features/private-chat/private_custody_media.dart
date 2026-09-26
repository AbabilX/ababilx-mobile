import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../attachments/data/models/attachment_handle.dart';
import '../attachments/data/models/attachment_url_key.dart';
import '../attachments/providers/attachment_providers.dart';
import '../messages/data/models/chat_attachment.dart';
import '../messages/data/models/chat_message.dart';

/// Whether this phone may say it holds [message]'s media, and so let the
/// server delete its copy (server 0160). A timed photo cannot be taken early:
/// its URL is withheld until the receiver opens it, and releasing the message
/// first would delete a photo nobody has seen. It is held until it expired.
bool privateMediaHoldsCustody(ChatMessageAttachment a) => a.timed && !a.expired;

/// Downloads every attachment of [messages] this phone does not hold yet —
/// ignoring the auto-download settings and the size cap, because the server's
/// copy is about to go and a tap-to-download later would find nothing — and
/// returns the ids of the messages whose media is all on disk. Only those may
/// be confirmed as taken.
///
/// A failed download is never "taken", permanent or not: a captive portal's
/// certificate or a CDN's 403 is classed permanent too, and confirming then
/// would delete the only copy. A file truly gone just waits out the cap.
Future<Set<String>> takePrivateMedia(
  Ref ref,
  List<ChatMessage> messages,
) async {
  if (messages.isEmpty) return const {};
  // Indexes which blobs each message points at, so deleting one later frees
  // its bytes — the same bookkeeping every arriving message gets.
  await ref.read(attachmentIntakeProvider).onMessages(messages);
  final queue = ref.read(attachmentQueueProvider);
  final blobs = ref.read(attachmentBlobStoreProvider);
  final taken = <String>{};
  for (final message in messages) {
    var ok = true;
    for (final a in message.attachments) {
      if (privateMediaHoldsCustody(a)) {
        ok = false;
        continue;
      }
      if (a.locked || a.expired || a.fileUrl.isEmpty) continue;
      final urlKey = attachmentUrlKey(a.fileUrl);
      if (urlKey.isEmpty || await blobs.isReady(urlKey)) continue;
      try {
        final handle = await queue.enqueue(a, userInitiated: true);
        if (handle.state != AttachmentTransferState.ready) ok = false;
      } catch (_) {
        ok = false;
      }
    }
    if (ok) taken.add(message.id);
  }
  return taken;
}

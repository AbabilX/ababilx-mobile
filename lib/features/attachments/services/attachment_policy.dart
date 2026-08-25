import '../../messages/data/models/chat_attachment.dart';
import '../attachment_config.dart';

/// What downloads on its own, and what waits for a tap.
///
/// Matches WhatsApp's default: photos and voice notes land silently so a chat
/// reads normally offline, while video, PDFs and documents — the expensive
/// ones — stay behind an explicit tap.
///
/// A legacy row with `sizeBytes == 0` passes here on purpose: the size gate is
/// enforced again at the network layer, which aborts on the `Content-Length`
/// header, so an unknown-size 80 MB "image" still never lands.
bool shouldAutoDownload(ChatMessageAttachment attachment) {
  if (attachment.locked || attachment.fileUrl.isEmpty) return false;
  if (!(attachment.isImage || attachment.isAudio)) return false;
  if (attachment.sizeBytes > autoDownloadMaxBytes) return false;
  return true;
}

/// Byte ceiling handed to the downloader for this job. An automatic transfer
/// aborts on the response header if the object turns out to be bigger than the
/// cap; a tapped one has no ceiling — the user asked for it.
int? downloadByteCeiling({required bool userInitiated}) =>
    userInitiated ? null : autoDownloadMaxBytes;

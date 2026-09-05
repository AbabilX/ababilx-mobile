import '../../../core/network/network_class.dart';
import '../../messages/data/models/chat_attachment.dart';
import '../attachment_config.dart';
import '../auto_download/auto_download_settings.dart';

/// What downloads on its own, and what waits for a tap.
///
/// The media-type half is the user's, set in Settings → Data and storage. The
/// two conditions kept out of their hands are here:
///
///  - a locked or URL-less attachment has nothing to fetch;
///  - a size ceiling, so "photos on cellular" cannot mean a 40 MB one.
///
/// A legacy row with `sizeBytes == 0` passes the ceiling on purpose: the size
/// gate is enforced again at the network layer, which aborts on the
/// `Content-Length` header, so an unknown-size 80 MB "image" still never lands.
bool shouldAutoDownload(
  ChatMessageAttachment attachment, {
  required AutoDownloadSettings settings,
  required NetworkClass network,
}) {
  if (attachment.locked || attachment.fileUrl.isEmpty) return false;
  if (attachment.sizeBytes > autoDownloadMaxBytes) return false;
  return settings.allows(autoDownloadMediaOf(attachment), network);
}

/// Byte ceiling handed to the downloader for this job. An automatic transfer
/// aborts on the response header if the object turns out to be bigger than the
/// cap; a tapped one has no ceiling — the user asked for it.
int? downloadByteCeiling({required bool userInitiated}) =>
    userInitiated ? null : autoDownloadMaxBytes;

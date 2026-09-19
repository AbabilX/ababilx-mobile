import '../../messages/data/models/chat_attachment.dart';
import '../data/local/attachment_blob_store.dart';
import '../data/models/attachment_handle.dart';
import '../data/models/media_dimensions.dart';
import 'attachment_handle_memory.dart';
import 'media_measure.dart';

/// Gives every ready picture and video its size, once, and keeps it.
///
/// Measured when the bytes land (a finished download, the sender adopting its
/// own upload) and, for files downloaded before sizes were recorded, the first
/// time one is resolved. Written to `attachment_blobs` so it outlives the
/// session and an eviction, and to [AttachmentHandleMemory] so a tile can size
/// itself on its first frame.
class AttachmentDimensionReader {
  AttachmentDimensionReader(
    this._blobs,
    this._memory, {
    this._measure = measureMediaFile,
  });

  final AttachmentBlobStore _blobs;
  final AttachmentHandleMemory _memory;
  final MediaMeasure _measure;

  /// One measurement per object however many bubbles show it.
  final Map<String, Future<MediaDimensions?>> _inFlight = {};

  /// [handle] with its size filled in, when it is a ready picture or video.
  /// Anything else comes back unchanged.
  Future<AttachmentHandle> complete(AttachmentHandle handle) async {
    if (handle.dimensions != null || !handle.isReady) return handle;
    final known = _memory.dimensionsOf(handle.urlKey);
    if (known != null) return handle.copyWith(dimensions: known);
    final video = looksLikeVideo(handle.contentType, handle.fileName);
    if (!video && !looksLikeImage(handle.contentType, handle.fileName)) {
      return handle;
    }
    final key = handle.urlKey;
    var pending = _inFlight[key];
    if (pending == null) {
      pending = _read(key, handle.localPath!, video);
      _inFlight[key] = pending;
      pending.whenComplete(() => _inFlight.remove(key)).ignore();
    }
    final size = await pending;
    return size == null ? handle : handle.copyWith(dimensions: size);
  }

  /// Loads recorded sizes for a page of messages before it is drawn, so rows
  /// the user has not scrolled past yet this session still mount at their
  /// final height. One indexed query per page; keys already known are skipped.
  Future<void> warm(Iterable<ChatMessageAttachment> attachments) async {
    final keys = <String>{};
    for (final attachment in attachments) {
      if (attachment.locked || !(attachment.isImage || attachment.isVideo)) {
        continue;
      }
      final key = _memory.urlKeyOf(attachment.fileUrl);
      if (key.isNotEmpty && _memory.dimensionsOf(key) == null) keys.add(key);
    }
    if (keys.isEmpty) return;
    final rows = await _blobs.readAll(keys);
    for (final row in rows.values) {
      final size = MediaDimensions.tryCreate(row.mediaWidth, row.mediaHeight);
      if (size != null) _memory.rememberDimensions(row.urlKey, size);
    }
  }

  Future<MediaDimensions?> _read(String urlKey, String path, bool video) async {
    try {
      // A finished download waits on this before it is announced, so a
      // platform call that never answers must cost a default frame, never a
      // tile stuck on "downloading". `then` re-types the future, or a measure
      // typed as non-null would refuse `onTimeout`'s null at runtime.
      final size = await _measure(path, video: video)
          .then<MediaDimensions?>((size) => size)
          .timeout(const Duration(seconds: 3), onTimeout: () => null);
      if (size != null) {
        _memory.rememberDimensions(urlKey, size);
        await _blobs.setDimensions(urlKey, size);
      }
      return size;
    } catch (_) {
      return null;
    }
  }
}

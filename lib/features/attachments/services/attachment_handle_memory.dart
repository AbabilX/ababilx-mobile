import '../data/models/attachment_handle.dart';
import '../data/models/attachment_url_key.dart';
import '../data/models/media_dimensions.dart';

/// What this session already knows about each attachment, readable
/// synchronously while a widget builds.
///
/// A row that scrolls away drops its `attachmentHandleProvider` (autoDispose).
/// When it comes back the provider starts over with no value, so for one frame
/// the tile drew its "looking it up" placeholder at a guessed size, and then
/// again at another size once the photo decoded. In a `reverse: true` list a
/// row below the viewport changing height pushes every row above it, which is
/// the jitter seen scrolling down to newer messages. The last known handle and
/// the measured size, read from here, make the first frame the final one.
///
/// Fed by every queue event and every resolve (see `AttachmentAuthority`),
/// warmed per feed page from `attachment_blobs`, and told by
/// `AttachmentBlobStore.onForget` when a file leaves the disk. Bounded, oldest
/// entry out first; losing an entry only costs one placeholder frame.
class AttachmentHandleMemory {
  AttachmentHandleMemory({this.capacity = 4000});

  final int capacity;
  final _handles = <String, AttachmentHandle>{};
  final _dimensions = <String, MediaDimensions>{};
  final _urlKeys = <String, String>{};

  /// [attachmentUrlKey] is a sha256 over a parsed URL — cheap once, not cheap
  /// on every build of every row while a list is flung.
  String urlKeyOf(String fileUrl) {
    final known = _urlKeys[fileUrl];
    if (known != null) return known;
    final key = attachmentUrlKey(fileUrl);
    _put(_urlKeys, fileUrl, key);
    return key;
  }

  AttachmentHandle? handleOf(String urlKey) =>
      urlKey.isEmpty ? null : _handles[urlKey];

  MediaDimensions? dimensionsOf(String urlKey) =>
      urlKey.isEmpty ? null : _dimensions[urlKey];

  void remember(AttachmentHandle handle) {
    final key = handle.urlKey;
    if (key.isEmpty) return;
    final size = handle.dimensions ?? _dimensions[key];
    final complete = size == null || handle.dimensions != null
        ? handle
        : handle.copyWith(dimensions: size);
    _put(_handles, key, complete);
    if (size != null) _put(_dimensions, key, size);
  }

  void rememberDimensions(String urlKey, MediaDimensions size) {
    if (urlKey.isEmpty) return;
    _put(_dimensions, urlKey, size);
    final handle = _handles[urlKey];
    if (handle != null && handle.dimensions == null) {
      _handles[urlKey] = handle.copyWith(dimensions: size);
    }
  }

  /// [urlKey] null forgets everything. The size is worth keeping when only
  /// the file went: the row keeps it too (see `AttachmentBlobStore`).
  void forget(String? urlKey, {required bool keepDimensions}) {
    if (urlKey == null) {
      _handles.clear();
      if (!keepDimensions) _dimensions.clear();
      return;
    }
    _handles.remove(urlKey);
    if (!keepDimensions) _dimensions.remove(urlKey);
  }

  void clear() {
    _handles.clear();
    _dimensions.clear();
    _urlKeys.clear();
  }

  /// A Dart map keeps insertion order, so re-inserting on write makes the
  /// first key the least recently written one.
  void _put<V>(Map<String, V> map, String key, V value) {
    map.remove(key);
    map[key] = value;
    if (map.length > capacity) map.remove(map.keys.first);
  }
}

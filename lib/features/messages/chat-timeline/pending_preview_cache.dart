import 'dart:collection';

/// Local files behind pending attachments, keyed by the URL they were uploaded
/// to.
///
/// The composer strip used to draw each pending thumbnail with
/// `CachedNetworkImage` pointed at the object that had just been uploaded —
/// so a photo taken two seconds ago was fetched back down from R2 before it
/// could be shown. The reference app draws the local file, and so do we now:
/// the upload records the path here, the tile reads it, and the network is not
/// involved.
///
/// Bounded, because entries outlive the send by design (a queued message keeps
/// its previews) and nothing else prunes them.
class PendingPreviewCache {
  const PendingPreviewCache._();

  static const int _max = 60;
  static final LinkedHashMap<String, String> _paths =
      LinkedHashMap<String, String>();

  static void put(String fileUrl, String localPath) {
    if (fileUrl.isEmpty || localPath.isEmpty) return;
    if (_paths.length >= _max) _paths.remove(_paths.keys.first);
    _paths[fileUrl] = localPath;
  }

  static String? get(String fileUrl) => _paths[fileUrl];

  static void forget(String fileUrl) => _paths.remove(fileUrl);
}

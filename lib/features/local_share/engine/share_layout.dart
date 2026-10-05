import 'package:path/path.dart' as p;

import 'protocol/share_file.dart';

/// Where a thread's files live: `<root>/<device id>/<message id>/…`.
///
/// Ids are checked against the id alphabet before they reach here and names
/// have passed `cleanShareFileName`, so nothing in a path came from the other
/// device unexamined.
class ShareLayout {
  const ShareLayout(this.root);

  final String root;

  String deviceDir(String deviceId) => p.join(root, deviceId);

  String messageDir(String deviceId, String messageId) =>
      p.join(root, deviceId, messageId);

  /// Final paths for the files of one message, in order. A folder keeps its
  /// tree; loose files that share a name (compared without case, as the
  /// desktop's disk compares them) get the file id in front.
  List<String> pathsFor(
    String deviceId,
    String messageId,
    List<ShareFile> files,
  ) {
    final dir = messageDir(deviceId, messageId);
    final used = <String>{};
    final out = <String>[];
    for (final file in files) {
      var relative = file.relPath ?? file.name;
      if (!used.add(relative.toLowerCase())) {
        final parent = p.posix.dirname(relative);
        final name = '${file.id}_${p.posix.basename(relative)}';
        relative = parent == '.' ? name : '$parent/$name';
        used.add(relative.toLowerCase());
      }
      out.add(p.joinAll([dir, ...relative.split('/')]));
    }
    return out;
  }
}

String sharePartPath(String localPath) => '$localPath.part';

import 'protocol/share_file.dart';

/// A file about to be sent. [owned]: the app may delete it with the bubble
/// (a voice note, a picker's cache copy) — never the user's own gallery file.
class ShareSource {
  const ShareSource(this.file, this.path, {this.owned = false});

  final ShareFile file;
  final String path;
  final bool owned;
}

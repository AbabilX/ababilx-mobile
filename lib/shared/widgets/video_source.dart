import 'dart:io';

import 'package:video_player/video_player.dart';

/// Where a video's bytes come from.
///
/// Chat plays from the downloaded file on disk; wall and CRM still stream from
/// the remote URL. Keeping that choice in one small value type means the
/// players themselves never branch on it.
class VideoSource {
  const VideoSource.url(this.url) : path = null;
  const VideoSource.file(this.path) : url = null;

  final String? url;
  final String? path;

  bool get isLocal => path != null && path!.isNotEmpty;

  /// Identity for `didUpdateWidget` — changing this is what re-initialises a
  /// controller (e.g. a download finishing under an already-mounted player).
  String get key => path ?? url ?? '';

  VideoPlayerController controller() {
    final local = path;
    if (local != null && local.isNotEmpty) {
      return VideoPlayerController.file(File(local));
    }
    return VideoPlayerController.networkUrl(Uri.parse(url ?? ''));
  }
}

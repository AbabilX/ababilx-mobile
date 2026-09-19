import 'dart:io';

import 'package:flutter/services.dart';

/// A poster frame the platform extracted, plus what it learned on the way.
class VideoThumb {
  const VideoThumb({
    required this.path,
    required this.width,
    required this.height,
    required this.duration,
  });

  final String path;
  final int width;
  final int height;
  final Duration duration;

  double get aspectRatio =>
      (width <= 0 || height <= 0) ? 16 / 9 : width / height;
}

/// One frame of a local video, decoded natively and cached on disk.
///
/// Exists so the timeline does not hold a live `VideoPlayerController` per
/// bubble: each of those is a MediaCodec decoder out of a small device-wide
/// pool, and a chat with a few videos in view empties it.
///
/// Android only. Everywhere else [forFile] answers null and the caller keeps
/// the live-controller poster.
class VideoThumbnails {
  const VideoThumbnails._();

  static const _channel = MethodChannel('com.ababilx.app/video');

  /// Per-path, and holding the *future* rather than the result: two bubbles
  /// pointing at the same file share one decode instead of racing.
  static final Map<String, Future<VideoThumb?>> _inFlight = {};

  /// Finished frames, readable while a widget builds. A `FutureBuilder`
  /// always paints one "waiting" frame even for a future that completed long
  /// ago, which drew a bubble that scrolled back into view as a spinner first.
  static final Map<String, VideoThumb> _ready = {};

  static bool get supported => Platform.isAndroid;

  /// The frame for [path] if this session has already extracted it.
  static VideoThumb? peek(String path) => _ready[path];

  static Future<VideoThumb?> forFile(String path, {int maxPx = 512}) {
    if (!supported || path.isEmpty) return Future.value(null);
    return _inFlight.putIfAbsent(path, () => _extract(path, maxPx));
  }

  static Future<VideoThumb?> _extract(String path, int maxPx) async {
    try {
      final raw = await _channel.invokeMapMethod<String, dynamic>('thumbnail', {
        'path': path,
        'maxPx': maxPx,
      });
      final file = raw?['path'] as String?;
      if (file == null || file.isEmpty) return null;
      return _ready[path] = VideoThumb(
        path: file,
        width: (raw?['width'] as num?)?.toInt() ?? 0,
        height: (raw?['height'] as num?)?.toInt() ?? 0,
        duration: Duration(
          milliseconds: (raw?['durationMs'] as num?)?.toInt() ?? 0,
        ),
      );
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  /// Held while a video is actually playing, released the moment it is not —
  /// a paused video has no claim on the screen.
  static Future<void> keepScreenOn(bool on) async {
    if (!supported) return;
    try {
      await _channel.invokeMethod<void>('keepScreenOn', {'on': on});
    } on MissingPluginException {
      // Older shell without the channel; the screen just behaves normally.
    } on PlatformException {
      // Same.
    }
  }
}

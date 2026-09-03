import 'dart:io';

import 'package:flutter/services.dart';

/// One file the native flow produced: already local, already edited.
class NativeMediaFile {
  const NativeMediaFile({
    required this.path,
    required this.fileName,
    required this.contentType,
    required this.sizeBytes,
  });

  final String path;
  final String fileName;
  final String contentType;
  final int sizeBytes;
}

/// What came back from the review screen: the album, and the one message
/// typed under it.
class NativeMediaSendResult {
  const NativeMediaSendResult({required this.files, required this.caption});

  final List<NativeMediaFile> files;
  final String caption;
}

/// Signal's picker, review screen and editor, drawn in Kotlin.
///
/// Android only. The Dart sheet in `media_grid_sheet.dart` stays as the iOS
/// path and as the fallback for an Android build where the channel is missing
/// — the composer asks [open] and falls through on null, so neither side has
/// to know which one ran.
class NativeMediaSend {
  const NativeMediaSend._();

  static const _channel = MethodChannel('com.ababilx.app/media_send');

  static bool get supported => Platform.isAndroid;

  static bool? _available;

  /// Whether the native flow can be opened at all. Checked before opening so
  /// a *cancelled* native flow is not mistaken for "no native flow" — that
  /// would pop the old Dart sheet the instant the user backed out of the new
  /// screen.
  static Future<bool> isAvailable() async {
    if (!supported) return false;
    final cached = _available;
    if (cached != null) return cached;
    try {
      final ok = await _channel.invokeMethod<bool>('available') ?? false;
      _available = ok;
      return ok;
    } on MissingPluginException {
      _available = false;
      return false;
    } on PlatformException {
      _available = false;
      return false;
    }
  }

  /// Returns null when the user backed out with nothing chosen. Callers must
  /// have asked [isAvailable] first; a null here means "cancelled", never
  /// "unsupported".
  static Future<NativeMediaSendResult?> open({
    int maxSelection = 10,
    bool allowVideo = true,
  }) async {
    if (!supported) return null;
    try {
      final raw = await _channel.invokeMapMethod<String, dynamic>('open', {
        'maxSelection': maxSelection,
        'allowVideo': allowVideo,
      });
      if (raw == null) return null;
      final items = (raw['items'] as List<dynamic>? ?? const []);
      final files = <NativeMediaFile>[];
      for (final item in items) {
        final map = (item as Map).cast<dynamic, dynamic>();
        final path = map['path'] as String? ?? '';
        if (path.isEmpty) continue;
        files.add(
          NativeMediaFile(
            path: path,
            fileName: map['name'] as String? ?? 'media',
            contentType: map['mime'] as String? ?? 'application/octet-stream',
            sizeBytes: (map['size'] as num?)?.toInt() ?? 0,
          ),
        );
      }
      if (files.isEmpty) return null;
      return NativeMediaSendResult(
        files: files,
        caption: raw['caption'] as String? ?? '',
      );
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }
}

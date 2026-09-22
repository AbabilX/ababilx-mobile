import 'dart:io' show Platform;

import 'package:flutter/services.dart';

/// Opens a Ghost Chat file in another app without it ever reaching the disk.
///
/// The bytes are handed to `GhostBlobProvider` (Kotlin), which keeps them in
/// this process's memory and serves them over a seekable, RAM-backed
/// descriptor — Signal's memory-blob model. Only the viewer the user picks
/// gets read permission, and only for that launch.
///
/// Android only. Everywhere else [available] is false and the caller falls
/// back to a temp file it deletes on the burn.
abstract final class GhostBlobs {
  static const _channel = MethodChannel('com.ababilx.app/ghost_blob');
  static bool _missing = false;

  /// Item id -> uri already held natively. Without it every open copied the
  /// whole file (up to 50 MB) into native memory again until the burn.
  static final _held = <String, String>{};

  static bool get available => Platform.isAndroid && !_missing;

  /// Holds [bytes] in memory and returns a `content://` uri for them — this
  /// app's own in-app players read it too (video, PDF). Null when unavailable.
  static Future<String?> put(
    String name,
    String mime,
    Uint8List bytes, {
    required String key,
  }) async {
    if (!available) return null;
    final held = _held[key];
    if (held != null) return held;
    try {
      final uri = await _channel.invokeMethod<String>('put', {
        'bytes': bytes,
        'name': name,
        'mime': mime,
      });
      if (uri == null || uri.isEmpty) return null;
      return _held[key] = uri;
    } on MissingPluginException {
      _missing = true;
      return null;
    } on PlatformException {
      return null;
    }
  }

  /// Holds [bytes] and opens them. False means nothing could open it — the
  /// caller shows that rather than falling back to writing a file.
  static Future<bool> open(
    String name,
    String mime,
    Uint8List bytes, {
    required String key,
  }) async {
    final uri = await put(name, mime, bytes, key: key);
    if (uri == null) return false;
    try {
      final opened = await _channel.invokeMethod<bool>('open', {
        'uri': uri,
        'mime': mime,
      });
      return opened ?? false;
    } on MissingPluginException {
      _missing = true;
      return false;
    } on PlatformException {
      return false;
    }
  }

  /// The burn: every held array is overwritten and dropped.
  static Future<void> clear() async {
    _held.clear();
    if (!available) return;
    try {
      await _channel.invokeMethod<void>('clear');
    } on MissingPluginException {
      _missing = true;
    } on PlatformException {
      // Nothing to recover: the arrays live in the other half.
    }
  }
}

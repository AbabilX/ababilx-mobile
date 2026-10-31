import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

/// One item in the device's photo/video library.
@immutable
class DeviceMediaItem {
  const DeviceMediaItem({
    required this.uri,
    required this.name,
    required this.mime,
    required this.sizeBytes,
    required this.width,
    required this.height,
    required this.isVideo,
    required this.durationMs,
  });

  factory DeviceMediaItem.fromMap(Map<Object?, Object?> map) => DeviceMediaItem(
    uri: map['uri'] as String? ?? '',
    name: map['name'] as String? ?? 'media',
    mime: map['mime'] as String? ?? 'application/octet-stream',
    sizeBytes: (map['size'] as num?)?.toInt() ?? 0,
    width: (map['width'] as num?)?.toInt() ?? 0,
    height: (map['height'] as num?)?.toInt() ?? 0,
    isVideo: map['isVideo'] == true,
    durationMs: (map['durationMs'] as num?)?.toInt() ?? 0,
  );

  final String uri;
  final String name;
  final String mime;
  final int sizeBytes;
  final int width;
  final int height;
  final bool isVideo;
  final int durationMs;

  @override
  bool operator ==(Object other) =>
      other is DeviceMediaItem && other.uri == uri;

  @override
  int get hashCode => uri.hashCode;
}

/// One MediaStore album — Camera, All media, Downloads, …
///
/// The reference app's wallpaper picker opens onto this list rather than a flat
/// "Recent" grid. [bucketId] is either a real `BUCKET_ID` or the synthetic
/// All-media id.
@immutable
class DeviceMediaFolder {
  const DeviceMediaFolder({
    required this.bucketId,
    required this.title,
    required this.count,
    required this.thumbnailUri,
    required this.isCamera,
  });

  factory DeviceMediaFolder.fromMap(Map<Object?, Object?> map) =>
      DeviceMediaFolder(
        bucketId: map['bucketId'] as String? ?? '',
        title: map['title'] as String? ?? 'Folder',
        count: (map['count'] as num?)?.toInt() ?? 0,
        thumbnailUri: map['thumbnailUri'] as String? ?? '',
        isCamera: map['isCamera'] == true,
      );

  final String bucketId;
  final String title;
  final int count;
  final String thumbnailUri;
  final bool isCamera;

  /// Stand-in [DeviceMediaItem] so folder tiles reuse [MediaThumbnail].
  DeviceMediaItem get thumbnailItem => DeviceMediaItem(
    uri: thumbnailUri,
    name: title,
    mime: 'image/jpeg',
    sizeBytes: 0,
    width: 0,
    height: 0,
    isVideo: false,
    durationMs: 0,
  );
}

/// Reads the device library directly, the way the reference app's attachment
/// keyboard does, instead of launching the system picker for every attachment.
///
/// The system picker is still the fallback — [available] is false when the
/// platform channel is missing or the user has denied media access, and every
/// caller is expected to fall back rather than show an empty grid.
class DeviceGallery {
  const DeviceGallery._();

  static const MethodChannel _channel = MethodChannel(
    'com.ababilx.app/media_gallery',
  );

  /// Matches Kotlin [MediaGalleryQuery.ALL_MEDIA_BUCKET_ID].
  static const String allMediaBucketId = 'ababilx.ALL_MEDIA';

  static bool get _android => !kIsWeb && Platform.isAndroid;

  /// Whether the in-app grid can be shown at all right now.
  static Future<bool> available() async {
    if (!_android) return false;
    return await _invoke<bool>('hasAccess', null) ?? false;
  }

  /// Asks for library access. Android 14's "Select photos" answers
  /// [PermissionStatus.limited], which is a usable grant, not a refusal.
  static Future<bool> requestAccess() async {
    if (!_android) return false;
    if (await available()) return true;
    final results = await [Permission.photos, Permission.videos].request();
    final granted = results.values.any(
      (status) => status.isGranted || status.isLimited,
    );
    // Below Android 13 both of the above map to storage.
    if (!granted) {
      final storage = await Permission.storage.request();
      if (!storage.isGranted && !storage.isLimited) return false;
    }
    return available();
  }

  /// Album list (Camera → All media → A–Z). Used by the wallpaper gallery.
  static Future<List<DeviceMediaFolder>> folders({
    String kind = 'image',
  }) async {
    if (!_android) return const [];
    final raw = await _invoke<List<Object?>>('folders', {'kind': kind});
    if (raw == null) return const [];
    return raw
        .whereType<Map<Object?, Object?>>()
        .map(DeviceMediaFolder.fromMap)
        .where((folder) => folder.bucketId.isNotEmpty)
        .toList(growable: false);
  }

  static Future<List<DeviceMediaItem>> page({
    int offset = 0,
    int limit = 60,
    String kind = 'all',
    String? bucketId,
  }) async {
    if (!_android) return const [];
    final raw = await _invoke<List<Object?>>('list', {
      'offset': offset,
      'limit': limit,
      'kind': kind,
      'bucketId': ?bucketId,
    });
    if (raw == null) return const [];
    return raw
        .whereType<Map<Object?, Object?>>()
        .map(DeviceMediaItem.fromMap)
        .where((item) => item.uri.isNotEmpty)
        .toList(growable: false);
  }

  /// A small JPEG for a grid tile, decoded natively at the size asked for so a
  /// 12-megapixel photo never becomes a full-size bitmap in the Dart heap.
  static Future<Uint8List?> thumbnail(String uri, {int maxPx = 256}) async {
    if (!_android) return null;
    return _invoke<Uint8List>('thumbnail', {'uri': uri, 'maxPx': maxPx});
  }

  /// Copies the original into the cache and returns its path. Uploading needs
  /// real bytes, and a `content://` grant does not outlive the picker.
  static Future<File?> materialize(DeviceMediaItem item) async {
    if (!_android) return null;
    final path = await _invoke<String>('copyToCache', {
      'uri': item.uri,
      'name': item.name,
    });
    if (path == null || path.isEmpty) return null;
    final file = File(path);
    return await file.exists() ? file : null;
  }

  static Future<T?> _invoke<T>(String method, Object? args) async {
    try {
      return await _channel.invokeMethod<T>(method, args);
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }
}

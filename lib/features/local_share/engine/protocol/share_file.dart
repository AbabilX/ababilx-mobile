import 'dart:convert';

import 'share_ids.dart';

const shareFileNameMaxBytes = 255;
const shareRelPathMaxBytes = 1024;

/// Metadata of one file inside an envelope.
class ShareFile {
  const ShareFile({
    required this.id,
    required this.name,
    required this.size,
    required this.mime,
    this.relPath,
    this.width,
    this.height,
    this.durationMs,
  });

  final String id;
  final String name;
  final int size;
  final String mime;

  /// `/`-separated path inside a sent folder; null for a loose file.
  final String? relPath;
  final int? width;
  final int? height;
  final int? durationMs;

  bool get isImage => mime.startsWith('image/');
  bool get isVideo => mime.startsWith('video/');
  bool get isAudio => mime.startsWith('audio/');

  /// Key order is part of the protocol fixtures (LOCAL_SHARE_PROTOCOL.md).
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'size': size,
    'mime': mime,
    if (relPath != null) 'rel_path': relPath,
    if (width != null) 'width': width,
    if (height != null) 'height': height,
    if (durationMs != null) 'duration_ms': durationMs,
  };

  static ShareFile? fromJson(Object? json, {required bool folder}) {
    if (json is! Map) return null;
    final id = json['id'];
    final name = cleanShareFileName(json['name']);
    final size = json['size'];
    if (!isShareId(id) || name == null || size is! int || size < 0) {
      return null;
    }
    String? relPath;
    if (folder) {
      relPath = cleanShareRelPath(json['rel_path']);
      if (relPath == null) return null;
    } else if (json['rel_path'] != null) {
      return null;
    }
    final mime = json['mime'];
    return ShareFile(
      id: id as String,
      name: name,
      size: size,
      mime: mime is String && mime.length <= 127 && mime.contains('/')
          ? mime.toLowerCase()
          : 'application/octet-stream',
      relPath: relPath,
      width: _positive(json['width']),
      height: _positive(json['height']),
      durationMs: _positive(json['duration_ms']),
    );
  }

  static int? _positive(Object? raw) => raw is int && raw > 0 ? raw : null;
}

final _control = RegExp(r'[\u0000-\u001F\u007F]');

/// A single path segment exactly as sent, or null when it could escape the
/// folder it is written into. Refused, never repaired: a sender that needs
/// repairing is not one to take files from.
String? cleanShareFileName(Object? raw) {
  if (raw is! String) return null;
  if (raw.isEmpty || raw == '.' || raw == '..') return null;
  if (raw.contains('/') || raw.contains(r'\') || raw.contains(_control)) {
    return null;
  }
  if (raw.trim() != raw && raw.trim().isEmpty) return null;
  if (utf8.encode(raw).length > shareFileNameMaxBytes) return null;
  return raw;
}

/// A relative `/`-separated path, every segment passing
/// [cleanShareFileName]; null otherwise (`../x`, `/etc/x`, `a//b`).
String? cleanShareRelPath(Object? raw) {
  if (raw is! String || raw.isEmpty) return null;
  if (utf8.encode(raw).length > shareRelPathMaxBytes) return null;
  final segments = raw.split('/');
  if (segments.length > 32) return null;
  for (final segment in segments) {
    if (cleanShareFileName(segment) == null) return null;
  }
  return raw;
}

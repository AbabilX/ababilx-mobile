import 'dart:convert';

import 'package:equatable/equatable.dart';

import '../../../shared/media/picked_media_file.dart';

/// One item another app handed us through the share sheet.
///
/// [uri] is a `content://` URI, not a path: nothing has been copied yet. The
/// bytes are pulled through the content resolver at send time — see
/// `ShareIntakeChannel.materialize`. Sharing a huge video and then backing out
/// therefore costs nothing.
class SharedFile extends Equatable {
  const SharedFile({
    required this.uri,
    required this.fileName,
    required this.contentType,
    required this.sizeBytes,
  });

  final String uri;
  final String fileName;
  final String contentType;

  /// -1 when the provider would not say. Unknown is not the same as huge, so
  /// an unknown size is allowed through and checked after the copy.
  final int sizeBytes;

  bool get isImage => contentType.toLowerCase().startsWith('image/');
  bool get isVideo => contentType.toLowerCase().startsWith('video/');
  bool get hasPreview => isImage || isVideo;

  /// Known to exceed the chat attachment cap, so the share screen can say so
  /// up front instead of failing halfway through an upload.
  bool get isTooLarge => sizeBytes > maxWorkspaceAttachmentBytes;

  factory SharedFile.fromJson(Map<String, dynamic> json) {
    final name = (json['name'] as String? ?? '').trim();
    final fileName = name.isEmpty ? 'shared-file' : name;
    return SharedFile(
      uri: json['uri'] as String? ?? '',
      fileName: fileName,
      // The sending app's declared type wins; our extension table is the
      // fallback for the many apps that declare nothing useful.
      contentType:
          _usableMime(json['mimeType'] as String?) ??
          contentTypeForFileName(fileName),
      sizeBytes: (json['size'] as num?)?.toInt() ?? -1,
    );
  }

  @override
  List<Object?> get props => [uri];
}

/// What another app shared: any number of files, plus whatever text came along
/// (a browser sends a URL, a notes app sends plain text).
class SharedPayload extends Equatable {
  const SharedPayload({this.files = const [], this.text = ''});

  final List<SharedFile> files;
  final String text;

  bool get isEmpty => files.isEmpty && text.trim().isEmpty;
  bool get hasFiles => files.isNotEmpty;

  /// Files small enough to actually send.
  List<SharedFile> get sendableFiles =>
      files.where((f) => !f.isTooLarge).toList();

  int get oversizedCount => files.length - sendableFiles.length;

  /// Parses the JSON `ShareIntakeBridge.parse` produces. Returns null for
  /// anything malformed or empty — a broken intent must look like no share at
  /// all, never like a crash.
  static SharedPayload? tryParse(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic>) return null;
      final files = <SharedFile>[];
      for (final entry in (json['files'] as List<dynamic>? ?? const [])) {
        if (entry is Map) {
          final file = SharedFile.fromJson(Map<String, dynamic>.from(entry));
          if (file.uri.isNotEmpty) files.add(file);
        }
      }
      final payload = SharedPayload(
        files: files,
        text: (json['text'] as String? ?? '').trim(),
      );
      return payload.isEmpty ? null : payload;
    } catch (_) {
      return null;
    }
  }

  @override
  List<Object?> get props => [files, text];
}

/// `*/*` and `application/octet-stream` are what an app sends when it does not
/// know either — no better than guessing from the extension ourselves.
String? _usableMime(String? mime) {
  final value = mime?.trim().toLowerCase() ?? '';
  if (value.isEmpty || value == '*/*' || value == 'application/octet-stream') {
    return null;
  }
  return value;
}

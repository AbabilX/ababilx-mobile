import 'dart:convert';

import 'share_file.dart';
import 'share_ids.dart';

enum ShareKind { text, files, voice, folder, delete }

const shareTextMaxBytes = 65536;
const shareMaxFiles = 5000;

/// One message as it crosses the network. Bytes of its files follow in
/// separate requests, keyed by [id] and each file's id.
class ShareEnvelope {
  const ShareEnvelope({
    required this.id,
    required this.kind,
    required this.sentAt,
    this.text,
    this.targetId,
    this.folderName,
    this.files = const [],
  });

  final String id;
  final ShareKind kind;

  /// Milliseconds since the epoch, by the sender's clock.
  final int sentAt;
  final String? text;
  final String? targetId;
  final String? folderName;
  final List<ShareFile> files;

  int get totalBytes => files.fold(0, (sum, f) => sum + f.size);

  /// Key order is part of the protocol fixtures (LOCAL_SHARE_PROTOCOL.md).
  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind.name,
    'sent_at': sentAt,
    if (text != null && text!.isNotEmpty) 'text': text,
    if (targetId != null) 'target_id': targetId,
    if (folderName != null) 'folder_name': folderName,
    if (files.isNotEmpty) 'files': [for (final f in files) f.toJson()],
  };

  String encode() => jsonEncode(toJson());

  /// Null when the envelope breaks any rule of the protocol. Nothing from a
  /// refused envelope is stored or written to disk.
  static ShareEnvelope? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final sentAt = json['sent_at'];
    final kind = _kind(json['kind']);
    if (!isShareId(id) || kind == null || sentAt is! int || sentAt < 0) {
      return null;
    }

    final text = json['text'];
    if (text != null &&
        (text is! String || utf8.encode(text).length > shareTextMaxBytes)) {
      return null;
    }
    final body = text is String && text.isNotEmpty ? text : null;

    final files = <ShareFile>[];
    final rawFiles = json['files'];
    if (rawFiles != null) {
      if (rawFiles is! List || rawFiles.length > shareMaxFiles) return null;
      final seen = <String>{};
      for (final raw in rawFiles) {
        final file = ShareFile.fromJson(raw, folder: kind == ShareKind.folder);
        if (file == null || !seen.add(file.id)) return null;
        files.add(file);
      }
    }

    final target = json['target_id'];
    final folder = json['folder_name'];
    switch (kind) {
      case ShareKind.text:
        if (body == null || files.isNotEmpty) return null;
      case ShareKind.delete:
        if (!isShareId(target) || files.isNotEmpty) return null;
      case ShareKind.voice:
        if (files.length != 1) return null;
      case ShareKind.files:
        if (files.isEmpty) return null;
      case ShareKind.folder:
        if (files.isEmpty || cleanShareFileName(folder) == null) return null;
    }

    return ShareEnvelope(
      id: id as String,
      kind: kind,
      sentAt: sentAt,
      text: body,
      targetId: kind == ShareKind.delete ? target as String : null,
      folderName: kind == ShareKind.folder ? cleanShareFileName(folder) : null,
      files: files,
    );
  }

  static ShareKind? _kind(Object? raw) {
    for (final kind in ShareKind.values) {
      if (kind.name == raw) return kind;
    }
    return null;
  }
}

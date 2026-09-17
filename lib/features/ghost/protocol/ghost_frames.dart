import 'dart:convert';

/// Wire format of the Ghost Chat data channel, version 1.
///
/// Text frames are JSON; binary frames are file chunks. One ordered, reliable
/// channel carries both, and the sender sends ONE file at a time, so a binary
/// frame always belongs to the last `file` header received. Text may
/// interleave with a file's chunks — the receiver does not care.
///
/// ```
/// {"t":"msg","id":"…","body":"hi","at":1726570000000}
/// {"t":"file","id":"…","name":"a.jpg","mime":"image/jpeg","size":12345,"at":…}
/// <binary chunk> × ceil(size / 16 KiB)
/// {"t":"typing","on":true}
/// {"t":"burn"}   {"t":"leave"}
/// ```
///
/// Nothing in a frame is ever written to disk or to the server.
sealed class GhostFrame {
  const GhostFrame();

  String encode();

  /// Null for anything malformed, oversized or from a newer protocol — a peer
  /// can send garbage, and garbage must not take this phone down.
  static GhostFrame? decode(String raw) {
    if (raw.length > maxFrameChars) return null;
    final Object? json;
    try {
      json = jsonDecode(raw);
    } catch (_) {
      return null;
    }
    if (json is! Map) return null;
    return switch (json['t']) {
      'msg' => GhostTextFrame._from(json),
      'file' => GhostFileHeader._from(json),
      'typing' => GhostTypingFrame(on: json['on'] == true),
      'burn' => const GhostBurnFrame(),
      'leave' => const GhostLeaveFrame(),
      _ => null,
    };
  }
}

/// Bounds a single text frame. Generous for a message, far below anything
/// that could stall the channel.
const maxFrameChars = 32 * 1024;
const maxBodyChars = 16 * 1024;

/// One chunk. Small enough for every SCTP stack a phone ships.
const ghostChunkBytes = 16 * 1024;

/// Per-file ceiling. Everything received lives in RAM until the burn, so this
/// is a memory bound as much as a transfer one.
const maxGhostFileBytes = 50 * 1024 * 1024;

class GhostTextFrame extends GhostFrame {
  const GhostTextFrame({
    required this.id,
    required this.body,
    required this.at,
  });
  final String id;
  final String body;
  final int at;

  static GhostTextFrame? _from(Map json) {
    final id = json['id'], body = json['body'], at = json['at'];
    if (id is! String || id.isEmpty || id.length > 64) return null;
    if (body is! String || body.isEmpty || body.length > maxBodyChars) {
      return null;
    }
    return GhostTextFrame(id: id, body: body, at: at is int ? at : 0);
  }

  @override
  String encode() => jsonEncode({'t': 'msg', 'id': id, 'body': body, 'at': at});
}

class GhostFileHeader extends GhostFrame {
  const GhostFileHeader({
    required this.id,
    required this.name,
    required this.mime,
    required this.size,
    required this.at,
  });
  final String id;
  final String name;
  final String mime;
  final int size;
  final int at;

  int get chunkCount => (size + ghostChunkBytes - 1) ~/ ghostChunkBytes;

  static GhostFileHeader? _from(Map json) {
    final id = json['id'], name = json['name'], mime = json['mime'];
    final size = json['size'], at = json['at'];
    if (id is! String || id.isEmpty || id.length > 64) return null;
    if (size is! int || size <= 0 || size > maxGhostFileBytes) return null;
    return GhostFileHeader(
      id: id,
      name: safeGhostFileName(name is String ? name : ''),
      mime: mime is String && mime.length <= 128
          ? mime
          : 'application/octet-stream',
      size: size,
      at: at is int ? at : 0,
    );
  }

  @override
  String encode() => jsonEncode({
    't': 'file',
    'id': id,
    'name': name,
    'mime': mime,
    'size': size,
    'at': at,
  });
}

class GhostTypingFrame extends GhostFrame {
  const GhostTypingFrame({required this.on});
  final bool on;

  @override
  String encode() => jsonEncode({'t': 'typing', 'on': on});
}

class GhostBurnFrame extends GhostFrame {
  const GhostBurnFrame();
  @override
  String encode() => '{"t":"burn"}';
}

class GhostLeaveFrame extends GhostFrame {
  const GhostLeaveFrame();
  @override
  String encode() => '{"t":"leave"}';
}

/// The peer chose this name, and it becomes a temp file name when a file is
/// opened: only its last path component survives, stripped of anything a
/// filesystem or a share sheet would treat specially.
String safeGhostFileName(String raw) {
  final last = raw.split(RegExp(r'[\\/]')).last;
  final cleaned = last
      .replaceAll(RegExp(r'[\x00-\x1f\x7f<>:"|?*]'), '')
      .replaceAll(RegExp(r'^\.+'), '')
      .trim();
  if (cleaned.isEmpty) return 'file';
  return cleaned.length > 120
      ? cleaned.substring(cleaned.length - 120)
      : cleaned;
}

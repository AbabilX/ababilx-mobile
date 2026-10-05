import '../protocol/share_envelope.dart';

enum ShareMessageStatus { sending, receiving, done, failed, canceled }

enum ShareFileStatus { pending, done, failed }

/// A device this one has met. [pairToken] is non-null once either side
/// pressed Accept; a blocked device keeps its row so it stays refused.
class ShareDeviceRecord {
  const ShareDeviceRecord({
    required this.deviceId,
    required this.name,
    required this.deviceType,
    this.userId,
    this.pairToken,
    this.blocked = false,
    this.lastIp = '',
    this.lastPort = 0,
    this.lastSeenMs = 0,
  });

  final String deviceId;
  final String name;
  final String deviceType;
  final String? userId;
  final String? pairToken;
  final bool blocked;
  final String lastIp;
  final int lastPort;
  final int lastSeenMs;

  bool get paired => pairToken != null && !blocked;
}

class ShareMessageRecord {
  const ShareMessageRecord({
    required this.id,
    required this.deviceId,
    required this.fromMe,
    required this.kind,
    required this.sentAt,
    required this.status,
    this.text,
    this.folderName,
    this.unread = false,
  });

  final String id;
  final String deviceId;
  final bool fromMe;
  final ShareKind kind;
  final int sentAt;
  final ShareMessageStatus status;
  final String? text;
  final String? folderName;
  final bool unread;
}

class ShareFileRecord {
  const ShareFileRecord({
    required this.id,
    required this.messageId,
    required this.name,
    required this.size,
    required this.mime,
    required this.localPath,
    this.relPath,
    this.width,
    this.height,
    this.durationMs,
    this.bytesDone = 0,
    this.status = ShareFileStatus.pending,
    this.owned = true,
  });

  final String id;
  final String messageId;
  final String name;
  final int size;
  final String mime;

  /// Final location. While receiving, the bytes are at `$localPath.part`.
  final String localPath;
  final String? relPath;
  final int? width;
  final int? height;
  final int? durationMs;
  final int bytesDone;
  final ShareFileStatus status;

  /// False for an outgoing file that still lives where the user picked it
  /// (a gallery photo): deleting the bubble must not delete their photo.
  final bool owned;

  bool get done => status == ShareFileStatus.done;
}

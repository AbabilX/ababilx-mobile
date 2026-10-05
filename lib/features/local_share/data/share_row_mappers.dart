import '../engine/protocol/share_envelope.dart';
import '../engine/store/share_records.dart';
import 'local_share_db.dart';

T _byName<T extends Enum>(List<T> values, String name, T fallback) {
  for (final value in values) {
    if (value.name == name) return value;
  }
  return fallback;
}

ShareDeviceRecord shareDeviceOf(LsDevice row) => ShareDeviceRecord(
  deviceId: row.deviceId,
  name: row.name,
  deviceType: row.deviceType,
  userId: row.userId,
  pairToken: row.pairToken,
  blocked: row.blocked,
  lastIp: row.lastIp,
  lastPort: row.lastPort,
  lastSeenMs: row.lastSeenMs,
);

ShareMessageRecord shareMessageOf(LsMessage row) => ShareMessageRecord(
  id: row.id,
  deviceId: row.deviceId,
  fromMe: row.fromMe,
  kind: _byName(ShareKind.values, row.kind, ShareKind.text),
  sentAt: row.sentAtMs,
  status: _byName(
    ShareMessageStatus.values,
    row.status,
    ShareMessageStatus.failed,
  ),
  text: row.body,
  folderName: row.folderName,
  unread: row.unread,
);

ShareFileRecord shareFileOf(LsFile row) => ShareFileRecord(
  id: row.id,
  messageId: row.messageId,
  name: row.name,
  size: row.size,
  mime: row.mime,
  localPath: row.localPath,
  relPath: row.relPath,
  width: row.width,
  height: row.height,
  durationMs: row.durationMs,
  bytesDone: row.bytesDone,
  status: _byName(ShareFileStatus.values, row.status, ShareFileStatus.failed),
  owned: row.owned,
);

import 'share_records.dart';
import 'share_store.dart';

/// In-memory [ShareStore] for tests.
class MemoryShareStore implements ShareStore {
  final devices = <String, ShareDeviceRecord>{};
  final messages = <String, ShareMessageRecord>{};
  final files = <String, List<ShareFileRecord>>{};

  @override
  Future<ShareDeviceRecord?> device(String deviceId) async => devices[deviceId];

  @override
  Future<void> saveDevice(ShareDeviceRecord device) async =>
      devices[device.deviceId] = device;

  @override
  Future<ShareMessageRecord?> message(String messageId) async =>
      messages[messageId];

  @override
  Future<List<ShareFileRecord>> filesOf(String messageId) async =>
      List.of(files[messageId] ?? const []);

  @override
  Future<ShareFileRecord?> file(String messageId, String fileId) async {
    for (final f in files[messageId] ?? const <ShareFileRecord>[]) {
      if (f.id == fileId) return f;
    }
    return null;
  }

  @override
  Future<bool> insertMessage(
    ShareMessageRecord message,
    List<ShareFileRecord> rows,
  ) async {
    if (messages.containsKey(message.id)) return false;
    messages[message.id] = message;
    files[message.id] = List.of(rows);
    return true;
  }

  @override
  Future<void> setMessageStatus(
    String messageId,
    ShareMessageStatus status,
  ) async {
    final m = messages[messageId];
    if (m == null) return;
    messages[messageId] = ShareMessageRecord(
      id: m.id,
      deviceId: m.deviceId,
      fromMe: m.fromMe,
      kind: m.kind,
      sentAt: m.sentAt,
      status: status,
      text: m.text,
      folderName: m.folderName,
      unread: m.unread,
    );
  }

  @override
  Future<void> setFileState(
    String messageId,
    String fileId, {
    required int bytesDone,
    required ShareFileStatus status,
  }) async {
    final rows = files[messageId];
    if (rows == null) return;
    final i = rows.indexWhere((f) => f.id == fileId);
    if (i < 0) return;
    final f = rows[i];
    rows[i] = ShareFileRecord(
      id: f.id,
      messageId: f.messageId,
      name: f.name,
      size: f.size,
      mime: f.mime,
      localPath: f.localPath,
      relPath: f.relPath,
      width: f.width,
      height: f.height,
      durationMs: f.durationMs,
      bytesDone: bytesDone,
      status: status,
      owned: f.owned,
    );
  }

  @override
  Future<List<ShareFileRecord>> deleteMessage(String messageId) async {
    messages.remove(messageId);
    return files.remove(messageId) ?? const [];
  }
}

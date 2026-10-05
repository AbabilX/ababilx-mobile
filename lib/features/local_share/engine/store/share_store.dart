import 'share_records.dart';

/// Everything the engine persists. The drift implementation is the app's;
/// tests use [MemoryShareStore]. The engine never touches a database itself.
abstract class ShareStore {
  Future<ShareDeviceRecord?> device(String deviceId);
  Future<void> saveDevice(ShareDeviceRecord device);

  Future<ShareMessageRecord?> message(String messageId);
  Future<List<ShareFileRecord>> filesOf(String messageId);
  Future<ShareFileRecord?> file(String messageId, String fileId);

  /// Inserts a message with its files; false (and no change) if the id is
  /// already known.
  Future<bool> insertMessage(
    ShareMessageRecord message,
    List<ShareFileRecord> files,
  );

  Future<void> setMessageStatus(String messageId, ShareMessageStatus status);
  Future<void> setFileState(
    String messageId,
    String fileId, {
    required int bytesDone,
    required ShareFileStatus status,
  });

  /// Removes the message and its file rows; returns the rows removed so the
  /// caller can delete what they own on disk.
  Future<List<ShareFileRecord>> deleteMessage(String messageId);
}

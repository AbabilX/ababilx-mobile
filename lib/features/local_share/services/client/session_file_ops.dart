import '../../models/session_state.dart';

/// Pure helpers for updating one file's progress within an immutable
/// [ShareSessionState].
ShareSessionState replaceFileProgress(
  ShareSessionState session,
  String fileId,
  FileTransferProgress progress,
) {
  final files = Map<String, FileTransferProgress>.from(session.files);
  files[fileId] = progress;
  return session.copyWith(files: files);
}

ShareSessionState markFileStatus(
  ShareSessionState session,
  String fileId,
  FileStatus status, {
  int? bytesTransferred,
  String? errorMessage,
}) {
  final current = session.files[fileId];
  if (current == null) return session;
  return replaceFileProgress(
    session,
    fileId,
    current.copyWith(
      status: status,
      bytesTransferred: bytesTransferred ?? current.bytesTransferred,
      errorMessage: errorMessage,
    ),
  );
}

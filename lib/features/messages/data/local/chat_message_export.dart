part of 'chat_message_store.dart';

/// The archive read, kept apart from the screen reads it must not be confused
/// with. A `part` rather than a separate library because it needs the same
/// private store handles the facade already chose between.
extension ChatMessageArchiveSource on ChatMessageStore {
  /// One ascending cursor over the whole local archive, for the exporter.
  ///
  /// Deliberately not [page]. `page` answers "what does this screen show
  /// next" — newest first, and filtered to `thread_root_id IS NULL`, which
  /// makes it structurally blind to thread replies and so unable to back one
  /// up. This reads every row of every conversation in (createdAt, id) order,
  /// so a backup can stream the history and resume from where it stopped.
  ///
  /// Reads the same store the rest of the facade prefers: SQLCipher on
  /// Android, drift elsewhere. Exporting from the wrong one would silently
  /// back up the rollback copy instead of the live history.
  Future<List<ChatMessage>> exportPage({
    int? afterMs,
    String? afterId,
    int limit = localPageCeiling,
  }) async {
    final native = _android;
    final bounded = limit.clamp(1, localPageCeiling);
    if (native == null) {
      return _drift.exportPage(
        afterMs: afterMs,
        afterId: afterId,
        limit: bounded,
      );
    }
    try {
      return await native.exportPage(
        afterMs: afterMs,
        afterId: afterId,
        limit: bounded,
      );
    } catch (_) {
      return _drift.exportPage(
        afterMs: afterMs,
        afterId: afterId,
        limit: bounded,
      );
    }
  }
}

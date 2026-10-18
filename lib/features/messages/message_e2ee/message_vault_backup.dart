part of 'message_vault.dart';

/// Opening stored messages for the local backup (features/local-backup).
///
/// The same keys as [MessageVaultDecrypt.decryptMessage], with one
/// difference that matters: a failure is `null`, never the "Unable to decrypt"
/// placeholder. A backup that wrote the placeholder would restore it as the
/// message's text — a lost message dressed up as a present one.
extension MessageVaultBackup on MessageVault {
  /// One backup run's opener: the readable text of a message, or null when
  /// this phone cannot open it.
  ///
  /// Ordered for thousands of rows in a row. The phone's own key first; then
  /// the text an earlier restore brought back (a row nobody's key opens any
  /// more, sealed before "start fresh"); the server last, and only ONCE per
  /// key version for the whole run. Asking the server per message — what the
  /// ordinary read path does, its misses remembered a minute — cost a request
  /// for every restored message of a chat whose old key is gone: minutes of
  /// "Backing up…" for a few thousand messages.
  ///
  /// An edited row skips the restored text until the server was asked: its
  /// restored words may predate the edit.
  Future<String?> Function(ChatMessage message) backupBodyOpener(
    String currentUserId,
  ) {
    // Per key version, for the run: what the phone holds (a miss is a disk
    // read every time otherwise) and what the server answered.
    final held = <String, Future<_DmKey?>>{};
    final asked = <String, Future<_DmKey?>>{};
    return (message) => _openForBackup(message, currentUserId, held, asked);
  }

  Future<String?> _openForBackup(
    ChatMessage message,
    String currentUserId,
    Map<String, Future<_DmKey?>> held,
    Map<String, Future<_DmKey?>> asked,
  ) async {
    if (!message.isEncrypted) return message.body;
    if (!isUnlocked || currentUserId.isEmpty) return null;
    final version = message.encryptionKeyVersion;
    final conversationId = message.conversationId;
    var key = await held.putIfAbsent(
      '$conversationId:$version',
      () => _localReadKey(
        conversationId,
        currentUserId,
        version,
      ).catchError((_) => null),
    );
    var restoredAsked = false;
    if (key == null && message.editedAt == null) {
      restoredAsked = true;
      final restored = await _restoredBody(message.id, currentUserId);
      if (restored != null) return restored;
    }
    if (key == null && version != null) {
      // Shared, so rows opened side by side wait on the same answer instead
      // of the first asking and the rest giving up on a key still coming.
      key = await asked.putIfAbsent(
        '$conversationId:$version',
        () => _readKey(
          conversationId,
          currentUserId,
          version,
        ).catchError((_) => null),
      );
    }
    if (key != null && key.version == version) {
      try {
        return await _openWithKey(key, message);
      } catch (_) {}
    }
    return restoredAsked ? null : _restoredBody(message.id, currentUserId);
  }
}

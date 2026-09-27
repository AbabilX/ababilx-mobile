part of 'message_vault.dart';

/// Opening stored messages for the local backup (features/local-backup).
///
/// The same key path as [MessageVaultDecrypt.decryptMessage], with one
/// difference that matters: a failure is `null`, never the "Unable to decrypt"
/// placeholder. A backup that wrote the placeholder would restore it as the
/// message's text — a lost message dressed up as a present one.
extension MessageVaultBackup on MessageVault {
  /// The readable text of [message], or null when this phone cannot open it.
  ///
  /// A message that came back from an earlier backup and that no key opens
  /// still answers, from its restored text, so the next backup keeps it.
  Future<String?> openBodyForBackup(
    ChatMessage message,
    String currentUserId,
  ) async {
    if (!message.isEncrypted) return message.body;
    if (!isUnlocked || currentUserId.isEmpty) return null;
    try {
      return await _openSealedBody(message, currentUserId);
    } catch (_) {
      return _restoredBody(message.id, currentUserId);
    }
  }
}

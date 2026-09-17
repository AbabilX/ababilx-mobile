part of 'message_vault.dart';

/// A sealed Ghost Chat signal: base64url ciphertext+tag and its 12-byte nonce.
class SealedGhostSignal {
  const SealedGhostSignal({required this.sealed, required this.nonce});
  final String sealed;
  final String nonce;
}

/// Ghost Chat signalling, sealed under the DM's own conversation key.
///
/// The phones talk over a WebRTC data channel, which DTLS encrypts — but the
/// DTLS certificate fingerprint rides inside the SDP, and the SDP rides through
/// the server. A relay that could rewrite it could stand in the middle of the
/// "peer-to-peer" link. Sealing every offer, answer and candidate under the
/// same key the DM's messages use means a rewritten signal simply fails to
/// open, so the link is exactly as end-to-end as the DM itself.
///
/// The AAD binds the ghost session and the sender, and its prefix differs from
/// a message's (`ababilx-dm-v1`), so a signal can never be replayed as a
/// message, into another session, or back at the person who sent it.
extension MessageVaultGhost on MessageVault {
  /// The key version the inviter will seal under — minted if the DM has none
  /// yet. Called once, before the invite, so both phones agree on it.
  Future<int> ghostKeyVersion({
    required String conversationId,
    required String currentUserId,
  }) async {
    final key = await _loadOrCreateKey(conversationId, currentUserId);
    return key.version;
  }

  Future<SealedGhostSignal> sealGhostSignal({
    required String conversationId,
    required String sessionId,
    required String senderId,
    required int keyVersion,
    required String payload,
  }) async {
    final key = await _ghostKey(conversationId, senderId, keyVersion);
    final nonce = _random(12);
    final box = await _aes.encrypt(
      utf8.encode(payload),
      secretKey: key.key,
      nonce: nonce,
      aad: _ghostAad(conversationId, keyVersion, sessionId, senderId),
    );
    return SealedGhostSignal(sealed: _b64(_boxBytes(box)), nonce: _b64(nonce));
  }

  /// Throws when the signal does not open — a tampered or foreign signal must
  /// never reach the peer connection.
  Future<String> openGhostSignal({
    required String conversationId,
    required String sessionId,
    required String senderId,
    required String currentUserId,
    required int keyVersion,
    required SealedGhostSignal signal,
  }) async {
    final key = await _ghostKey(conversationId, currentUserId, keyVersion);
    final clear = await _aes.decrypt(
      _box(signal.sealed, signal.nonce),
      secretKey: key.key,
      aad: _ghostAad(conversationId, keyVersion, sessionId, senderId),
    );
    return utf8.decode(clear);
  }

  Future<_DmKey> _ghostKey(
    String conversationId,
    String self,
    int version,
  ) async {
    final key = await _readKey(conversationId, self, version);
    if (key == null || key.version != version) {
      throw StateError('Secure message key is unavailable');
    }
    return key;
  }

  List<int> _ghostAad(
    String conversationId,
    int version,
    String sessionId,
    String senderId,
  ) => utf8.encode(
    'ababilx-ghost-v1:$conversationId:$version:$sessionId:$senderId',
  );
}

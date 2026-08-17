part of 'message_vault.dart';

/// Per-conversation AES key, tagged with the key version it belongs to.
class _DmKey {
  const _DmKey({required this.version, required this.key});
  final int version;
  final SecretKey key;
}

extension MessageVaultKeys on MessageVault {
  Future<_DmKey> _loadOrCreateKey(
    String conversationId,
    String self,
    String peer,
  ) async {
    final loaded = await _loadKey(conversationId, self);
    if (loaded != null) return loaded;
    final identity = _identity;
    final publicJwk = _publicJwk;
    if (identity == null || publicJwk == null) {
      throw StateError('Enter your message PIN first');
    }
    final dmKey = await _aes.newSecretKey();
    final peerResult = await _repo.getE2eePublicKey(peer);
    final peerPublic = Map<String, dynamic>.from(
      peerResult['public_key'] as Map,
    );
    final envelopes = <String, dynamic>{
      self: await _wrapKey(dmKey, self, publicJwk),
      peer: await _wrapKey(dmKey, peer, peerPublic),
    };
    final saved = await _repo.createE2eeConversationKey(
      conversationId,
      envelopes,
    );
    final entry = _DmKey(
      version: (saved['key_version'] as num).toInt(),
      key: await _unwrapKey(
        Map<String, dynamic>.from(saved['envelope'] as Map),
        self,
      ),
    );
    _keys[conversationId] = entry;
    return entry;
  }

  /// Reads the caller's newest envelope for [conversationId]. Pass
  /// [refresh] to bypass the in-memory cache after the peer rotated the key.
  Future<_DmKey?> _loadKey(
    String conversationId,
    String self, {
    bool refresh = false,
  }) async {
    final cached = _keys[conversationId];
    if (cached != null && !refresh) return cached;
    if (_identity == null) return null;
    final status = await _repo.getE2eeConversationKey(conversationId);
    if (status['exists'] != true) return null;
    final key = Map<String, dynamic>.from(status['key'] as Map);
    final entry = _DmKey(
      version: (key['key_version'] as num).toInt(),
      key: await _unwrapKey(
        Map<String, dynamic>.from(key['envelope'] as Map),
        self,
      ),
    );
    _keys[conversationId] = entry;
    return entry;
  }

  Future<Map<String, dynamic>> _wrapKey(
    SecretKey key,
    String recipient,
    Map<String, dynamic> publicJwk,
  ) async {
    final ephemeral = P256Ecdh.newKeyPair();
    final nonce = _random(12);
    final wrappingKey = await _envelopeKey(ephemeral, publicJwk);
    final box = await _aes.encrypt(
      await key.extractBytes(),
      secretKey: wrappingKey,
      nonce: nonce,
      aad: utf8.encode('ababilx-dm-key-v1:$recipient'),
    );
    return {
      'ephemeral_public_key': _publicJwkFromIdentity(ephemeral),
      'nonce': _b64(nonce),
      'ciphertext': _b64(_boxBytes(box)),
    };
  }

  Future<SecretKey> _unwrapKey(
    Map<String, dynamic> envelope,
    String userId,
  ) async {
    final identity = _identity;
    if (identity == null) {
      throw StateError('Enter your message PIN first');
    }
    final key = await _envelopeKey(
      identity,
      Map<String, dynamic>.from(envelope['ephemeral_public_key'] as Map),
    );
    final clear = await _aes.decrypt(
      _box(envelope['ciphertext'] as String, envelope['nonce'] as String),
      secretKey: key,
      aad: utf8.encode('ababilx-dm-key-v1:$userId'),
    );
    return SecretKey(clear);
  }

  /// SHA-256 over the raw ECDH X coordinate — the same derivation the web
  /// client performs with `deriveBits(256)` + `digest("SHA-256")`.
  Future<SecretKey> _envelopeKey(
    P256KeyPair private,
    Map<String, dynamic> remote,
  ) async {
    final shared = P256Ecdh.sharedSecretX(
      privateD: private.d,
      remoteX: _bytes(remote['x'] as String),
      remoteY: _bytes(remote['y'] as String),
    );
    return SecretKey((await Sha256().hash(shared)).bytes);
  }
}

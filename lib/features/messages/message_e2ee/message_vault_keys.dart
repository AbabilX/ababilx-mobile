part of 'message_vault.dart';

/// Per-conversation AES key, tagged with the key version it belongs to.
///
/// [stale] marks a version the server reported as unreadable by some member —
/// sealing to it would produce a message they could never open — so the next
/// send rotates instead of reusing it.
class _DmKey {
  const _DmKey({
    required this.version,
    required this.key,
    this.stale = false,
  });
  final int version;
  final SecretKey key;
  final bool stale;
}

extension MessageVaultKeys on MessageVault {
  Future<_DmKey> _loadOrCreateKey(
    String conversationId,
    String self,
    String peer,
  ) async {
    final loaded = await _loadKey(conversationId, self);
    if (loaded != null && !loaded.stale) return loaded;
    return _createKey(conversationId, self, peer);
  }

  /// Re-keys a conversation and seals [text] under the new key.
  ///
  /// Called when the server refuses a send because the key it was sealed with
  /// is unreadable to the other side — in practice they started a fresh
  /// identity, which drops their envelope while this device's own envelope
  /// stays valid, so nothing local looks wrong. Dropping the cache first stops
  /// a key that went stale mid-session from being handed back.
  Future<EncryptedDmPayload> rekeyAndEncrypt({
    required String conversationId,
    required String text,
    required String currentUserId,
    required String peerUserId,
  }) async {
    _keys.remove(conversationId);
    final key = await _createKey(conversationId, currentUserId, peerUserId);
    return _seal(conversationId, text, currentUserId, key);
  }

  /// Mints a conversation key and wraps it for both members' current public
  /// keys. The server rotates to a new version whenever somebody cannot read
  /// the present one, so this is the first-key path and the re-key path alike.
  Future<_DmKey> _createKey(
    String conversationId,
    String self,
    String peer,
  ) async {
    final identity = _identity;
    final publicJwk = _publicJwk;
    if (identity == null || publicJwk == null) {
      throw StateError('Secure messages are not ready on this device yet');
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
    final pending = _keyLoads[conversationId];
    if (pending != null && !refresh) return pending;
    final load = _fetchKey(conversationId, self);
    _keyLoads[conversationId] = load;
    try {
      return await load;
    } finally {
      if (identical(_keyLoads[conversationId], load)) {
        _keyLoads.remove(conversationId);
      }
    }
  }

  Future<_DmKey?> _fetchKey(String conversationId, String self) async {
    final status = await _repo.getE2eeConversationKey(conversationId);
    if (status['exists'] != true) return null;
    final key = Map<String, dynamic>.from(status['key'] as Map);
    final missing = (status['missing_member_ids'] as List?) ?? const [];
    // An envelope that will not open is indistinguishable from having none:
    // unwrapping is pure computation, so this is a corrupt or hostile row, not
    // a network blip. Reporting "no key" lets the next send mint a fresh
    // version instead of leaving the conversation unable to send at all.
    final SecretKey opened;
    try {
      opened = await _unwrapKey(
        Map<String, dynamic>.from(key['envelope'] as Map),
        self,
      );
    } catch (_) {
      return null;
    }
    final entry = _DmKey(
      version: (key['key_version'] as num).toInt(),
      key: opened,
      // Hand the surviving key to anyone who lost theirs BEFORE deciding this
      // key is stale: a filled gap restores their history and leaves nothing
      // to rotate.
      stale:
          missing.isNotEmpty &&
          !await _backfillKeys(
            conversationId,
            self,
            (status['gaps'] as List?) ?? const [],
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
      throw StateError('Secure messages are not ready on this device yet');
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

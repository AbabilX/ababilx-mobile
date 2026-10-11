part of 'message_vault.dart';

/// Per-conversation AES key, tagged with the key version it belongs to.
///
/// [stale] marks a version the server reported as unreadable by some member —
/// sealing to it would produce a message they could never open — so the next
/// send rotates instead of reusing it.
class _DmKey {
  const _DmKey({required this.version, required this.key, this.stale = false});
  final int version;
  final SecretKey key;
  final bool stale;
}

extension MessageVaultKeys on MessageVault {
  Future<_DmKey> _loadOrCreateKey(String conversationId, String self) async {
    final loaded = await _loadKey(conversationId, self);
    if (loaded != null && !loaded.stale) return loaded;
    // No key at all is the only path allowed to answer "not ready" rather
    // than fail — a stale key means the conversation is already encrypted.
    return _createKey(conversationId, self, firstKey: loaded == null);
  }

  /// Re-keys a conversation and seals [text] under the new key.
  ///
  /// Called when the server refuses a send because the key it was sealed with
  /// is unreadable to somebody in the conversation. Three ways that happens:
  /// they started a fresh identity, which drops their envelope while this
  /// device's own stays valid so nothing local looks wrong; they joined after
  /// the key was minted; or somebody was removed and the key was retired, which
  /// looks like nothing at all from here. Dropping the cache first stops a key
  /// that went stale mid-session from being handed back.
  Future<EncryptedDmPayload> rekeyAndEncrypt({
    required String conversationId,
    required String text,
    required String currentUserId,
  }) async {
    _keys.remove(conversationId);
    final key = await _createKey(conversationId, currentUserId);
    return _seal(conversationId, text, currentUserId, key);
  }

  /// Mints a conversation key and wraps it for every member's current public
  /// key. The roster comes from the server, which is what makes this work for a
  /// group: a DM caller knew both ids, a group caller does not, and the set
  /// moves under it whenever somebody joins or leaves. The server rotates to a
  /// new version whenever the current one is spent, so this is the first-key
  /// path, the re-key path after a fresh identity, and the re-key path after a
  /// removal alike.
  ///
  /// Own key comes from this device, never from the response — the server is
  /// the only source for everybody else's, and there is no reason to extend
  /// that to our own.
  Future<_DmKey> _createKey(
    String conversationId,
    String self, {
    bool firstKey = false,
  }) async {
    final identity = _identity;
    final publicJwk = _publicJwk;
    if (identity == null || publicJwk == null) {
      throw StateError('Secure messages are not ready on this device yet');
    }
    final roster = await _repo.getE2eeConversationMembers(conversationId);
    final unready = (roster['unready_member_ids'] as List?) ?? const [];
    // A key cannot be sealed to somebody with no identity, and one that skipped
    // them would lock them out of their own conversation.
    if (unready.isNotEmpty) {
      final members = (roster['members'] as List?) ?? const [];
      final message = unready.length == 1 && members.length <= 1
          ? 'This person must set up secure messages before you can send a DM'
          : 'Everyone here must open AbabilX once before this chat can be encrypted';
      throw firstKey ? ChatKeyNotReady(message) : StateError(message);
    }
    final dmKey = await _aes.newSecretKey();
    final envelopes = <String, dynamic>{};
    for (final entry in (roster['members'] as List? ?? const [])) {
      final member = Map<String, dynamic>.from(entry as Map);
      final userId = member['user_id'] as String;
      final publicKey = userId == self
          ? publicJwk
          : Map<String, dynamic>.from(member['public_key'] as Map);
      onSealingTo?.call(self, userId, publicKey);
      envelopes[userId] = await _wrapKey(dmKey, userId, publicKey);
    }
    final saved = await _repo.createE2eeConversationKey(
      conversationId,
      envelopes,
    );
    final envelope = Map<String, dynamic>.from(saved['envelope'] as Map);
    final version = (saved['key_version'] as num).toInt();
    final SecretKey opened;
    try {
      opened = await _unwrapKey(envelope, self);
    } catch (_) {
      // A rival's key won the race and its envelope for us does not open. This
      // send fails; the report makes the next one rotate.
      await _reportUnreadableEnvelope(conversationId, version, identity);
      rethrow;
    }
    final entry = _DmKey(version: version, key: opened);
    _keys[conversationId] = entry;
    onKeyHeld?.call(self, conversationId);
    await _cacheEnvelope(conversationId, entry.version, envelope);
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
    // rekey_required is the server's own verdict and covers what the roster
    // cannot show: a key retired because somebody was REMOVED leaves everyone
    // still here holding a good envelope. Fall back to the roster gap on a
    // server that predates the field.
    final missing = (status['missing_member_ids'] as List?) ?? const [];
    final spent = status['rekey_required'] as bool? ?? missing.isNotEmpty;
    // An envelope that will not open is indistinguishable from having none:
    // unwrapping is pure computation, so this is a corrupt or mis-sealed row,
    // not a network blip. Reporting it drops the row server-side, so "no key"
    // here really does let the next send mint a fresh version instead of being
    // handed the same row and leaving the conversation unable to send.
    final envelope = Map<String, dynamic>.from(key['envelope'] as Map);
    final version = (key['key_version'] as num).toInt();
    final identity = _identity;
    final SecretKey opened;
    try {
      opened = await _unwrapKey(envelope, self);
    } catch (_) {
      // Reported before answering, so the send this is about to fall back to
      // finds the version stale and rotates instead of being handed the same
      // row again.
      await _reportUnreadableEnvelope(conversationId, version, identity);
      return null;
    }
    // Filed away before the staleness verdict below, which can involve another
    // round trip: the envelope is good either way, and a key that reached this
    // device once should never need the network to be read again.
    await _cacheEnvelope(conversationId, version, envelope);
    // Hand the surviving key to anyone who lost theirs BEFORE deciding this key
    // is stale: a filled gap restores their history and leaves nothing to
    // rotate. Run whether or not the key is spent — a gap at an OLDER version
    // (somebody reset, and a rotation already happened) is the history they
    // lost, and `spent && await ...` used to skip exactly that case.
    final repaired = await _backfillKeys(
      conversationId,
      self,
      (status['gaps'] as List?) ?? const [],
    );
    final entry = _DmKey(
      version: version,
      key: opened,
      stale: spent && !repaired,
    );
    _keys[conversationId] = entry;
    onKeyHeld?.call(self, conversationId);
    return entry;
  }
}

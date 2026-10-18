part of 'message_vault.dart';

/// Reading a conversation key from what this device already holds.
///
/// The key used to live in memory alone, so the first message of every cold
/// start had to reach the network before it could be read — and with no
/// network at all, every message in every chat drew "Unable to decrypt this
/// message" over history sitting on the disk right beside it. Signal decrypts
/// once on receipt and stores the plaintext; we keep ciphertext at rest and
/// store the sealed KEY instead, which lands in the same place without putting
/// message text on disk.
extension MessageVaultKeyCache on MessageVault {
  /// Files an envelope away for later. Best-effort on purpose: a cache write
  /// that fails must never take down the decrypt that prompted it.
  Future<void> _cacheEnvelope(
    String conversationId,
    int version,
    Map<String, dynamic> envelope,
  ) async {
    final cache = _keyCache;
    if (cache == null) return;
    try {
      await cache.save(conversationId, version, envelope);
    } catch (_) {}
  }

  /// Opens the stored envelope for one exact version.
  ///
  /// An envelope that will not open belongs to an identity this device no
  /// longer has — unwrapping is pure computation, so it is not a network blip
  /// — and is dropped rather than retried once per message on screen.
  Future<_DmKey?> _storedKey(
    String conversationId,
    String self,
    int version,
  ) async {
    final cache = _keyCache;
    if (cache == null || _identity == null) return null;
    Map<String, dynamic>? envelope;
    try {
      envelope = await cache.read(conversationId, version);
    } catch (_) {
      return null;
    }
    if (envelope == null) return null;
    try {
      final entry = _DmKey(
        version: version,
        key: await _unwrapKey(envelope, self),
      );
      _readKeys['$conversationId:$version'] = entry;
      return entry;
    } catch (_) {
      try {
        await cache.remove(conversationId, version);
      } catch (_) {}
      return null;
    }
  }

  /// The key a message ALREADY WRITTEN was sealed with.
  ///
  /// Order is the whole fix: memory, then this device's own copy, and only
  /// then the server. Disk before network means opening a chat costs no
  /// request, and a phone with no connection reads its history instead of a
  /// screenful of placeholders.
  ///
  /// Staleness is deliberately not consulted here. `rekey_required` decides
  /// what the next SEND may seal to and has nothing to say about reading a
  /// message that was written months ago; the send paths still go through
  /// [MessageVaultKeys._loadKey], which is unchanged.
  ///
  /// Matching on the exact version also fixes reading across a rotation:
  /// `GET .../e2ee-key` only ever returns the newest envelope, so a version
  /// older than that comes from this cache or, when this device never stored
  /// it (a reinstall, a phone closed while it was current), from
  /// [MessageVaultKeyVersions._fetchKeyVersion].
  Future<_DmKey?> _readKey(
    String conversationId,
    String self,
    int? version,
  ) async {
    if (version == null) return null;
    final live = _keys[conversationId];
    if (live != null && live.version == version) return live;
    final held = _readKeys['$conversationId:$version'];
    if (held != null) return held;
    final slot = '$conversationId:$version';
    final inFlight = _readKeyLoads[slot];
    if (inFlight != null) return inFlight;
    final load = _resolveReadKey(conversationId, self, version);
    _readKeyLoads[slot] = load;
    try {
      return await load;
    } finally {
      if (identical(_readKeyLoads[slot], load)) _readKeyLoads.remove(slot);
    }
  }

  /// [_readKey] without the network: memory, then this device's own stored
  /// envelope. Single-flight like it, for the same fifty-messages reason.
  Future<_DmKey?> _localReadKey(
    String conversationId,
    String self,
    int? version,
  ) async {
    if (version == null) return null;
    final live = _keys[conversationId];
    if (live != null && live.version == version) return live;
    final slot = '$conversationId:$version';
    final held = _readKeys[slot];
    if (held != null) return held;
    final inFlight = _localKeyLoads[slot];
    if (inFlight != null) return inFlight;
    final load = _storedKey(conversationId, self, version);
    _localKeyLoads[slot] = load;
    try {
      return await load;
    } finally {
      if (identical(_localKeyLoads[slot], load)) _localKeyLoads.remove(slot);
    }
  }

  Future<_DmKey?> _resolveReadKey(
    String conversationId,
    String self,
    int version,
  ) async {
    final stored = await _localReadKey(conversationId, self, version);
    if (stored != null) return stored;
    try {
      var key = await _loadKey(conversationId, self);
      // A newer version than this device knows means the other side rotated,
      // so the cached key is stale and worth one refetch.
      if (key != null && version > key.version) {
        key = await _loadKey(conversationId, self, refresh: true);
      }
      if (key != null && key.version == version) return key;
      // Older than the newest version, or no newest one this device can open:
      // either way the envelope for exactly this version may still be waiting
      // on the server. Newer than the newest after a refresh is a version the
      // server has never heard of, and asking again would not change that.
      if (key == null || version < key.version) {
        return await _fetchKeyVersion(conversationId, self, version);
      }
    } catch (_) {
      // Offline, or the server is unreachable. Nothing more to try — the disk
      // was already asked, and asking it twice would answer the same.
    }
    return null;
  }
}

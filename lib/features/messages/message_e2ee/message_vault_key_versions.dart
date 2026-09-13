part of 'message_vault.dart';

/// How long an answer of "no envelope for that version" is believed before the
/// server is asked again. Long enough that a screenful of messages sealed under
/// a version this account never held costs one request rather than one per
/// rebuild; short enough that a backfill another member runs a minute later —
/// the repair after an identity reset — is picked up without a restart.
const _versionMissRetry = Duration(minutes: 1);

/// Reading a message sealed under a key version that is no longer the newest.
///
/// `GET .../e2ee-key` answers "what do I seal with?", so it only ever returns
/// the newest envelope. A group rotates whenever somebody joins, leaves or
/// resets, and every message keeps the version it was sealed under. Before this
/// the only copy of a retired version this device could read was one it had
/// stored itself — so a reinstall restored with the recovery code, or a phone
/// that was not open while that version was current, drew "Unable to decrypt"
/// over everything written before the last rotation, while this account's own
/// envelopes for those versions sat on the server unread.
extension MessageVaultKeyVersions on MessageVault {
  /// The key for exactly [version], fetched from the server and filed away on
  /// this device so it is never asked for twice.
  ///
  /// Concurrent callers share one request: a page of messages under one retired
  /// version would otherwise send one identical request per message.
  Future<_DmKey?> _fetchKeyVersion(
    String conversationId,
    String self,
    int version,
  ) {
    final id = '$conversationId:$version';
    final missed = _versionMisses[id];
    if (missed != null &&
        DateTime.now().difference(missed) < _versionMissRetry) {
      return Future.value();
    }
    final pending = _versionLoads[id];
    if (pending != null) return pending;
    final load = _openKeyVersion(conversationId, self, version);
    _versionLoads[id] = load;
    return load.whenComplete(() {
      if (identical(_versionLoads[id], load)) _versionLoads.remove(id);
    });
  }

  Future<_DmKey?> _openKeyVersion(
    String conversationId,
    String self,
    int version,
  ) async {
    final id = '$conversationId:$version';
    final identity = _identity;
    if (identity == null) return null;
    final result = await _repo.getE2eeConversationKeyVersions(conversationId, [
      version,
    ]);
    // Locked, or a different identity adopted, while the request was out: this
    // envelope belongs to a vault state that no longer exists.
    if (!identical(identity, _identity)) return null;
    for (final raw in (result['envelopes'] as List? ?? const [])) {
      final item = Map<String, dynamic>.from(raw as Map);
      if ((item['key_version'] as num?)?.toInt() != version) continue;
      final envelope = Map<String, dynamic>.from(item['envelope'] as Map);
      final SecretKey key;
      try {
        key = await _unwrapKey(envelope, self);
      } catch (_) {
        // Sealed to an identity this account does not hold. Pure computation,
        // so asking again in a second would answer the same — but reporting it
        // lets a member who still holds the key re-wrap it, and the miss runs
        // out in time to pick that up.
        _versionMisses[id] = DateTime.now();
        await _reportUnreadableEnvelope(conversationId, version, identity);
        return null;
      }
      if (!identical(identity, _identity)) return null;
      final entry = _DmKey(version: version, key: key);
      _readKeys[id] = entry;
      await _cacheEnvelope(conversationId, version, envelope);
      return entry;
    }
    // Nothing to hand back: a version from before this account joined, or one
    // lost to an identity reset that nobody has backfilled yet.
    _versionMisses[id] = DateTime.now();
    return null;
  }
}

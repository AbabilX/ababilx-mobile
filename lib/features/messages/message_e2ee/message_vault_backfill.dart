part of 'message_vault.dart';

/// Gives an existing conversation key back to members who lost it.
///
/// Someone who starts a fresh identity keeps their messages but loses every key
/// envelope, because each was sealed to the identity they no longer have. The
/// keys themselves are untouched — they live on the other members' devices.
/// This opens the ones this device holds and re-seals them to the missing
/// members' current public identities, which is what makes their history
/// readable again. Minting a new key version, the other repair, only fixes
/// messages from this moment on.
extension MessageVaultBackfill on MessageVault {
  /// Fills every gap the server reported for [conversationId], returning true
  /// when at least one envelope landed.
  ///
  /// Best-effort by design: this runs beside a key load, so a failure must
  /// degrade to "their history stays sealed", never to a broken conversation.
  Future<bool> _backfillKeys(
    String conversationId,
    String self,
    List<dynamic> gaps,
  ) async {
    if (gaps.isEmpty || _backfilled.contains(conversationId)) return false;
    _backfilled.add(conversationId);
    final identity = _identity;
    try {
      final envelopes = <Map<String, dynamic>>[];
      for (final raw in gaps) {
        final gap = Map<String, dynamic>.from(raw as Map);
        final version = (gap['key_version'] as num).toInt();
        final envelope = Map<String, dynamic>.from(gap['envelope'] as Map);
        final SecretKey key;
        try {
          key = await _unwrapKey(envelope, self);
        } catch (_) {
          // Our own copy of this version is the broken one. Nothing to hand
          // on from it; reporting it lets somebody else hand it to us, and
          // the other versions in this list are still worth filling.
          await _reportUnreadableEnvelope(conversationId, version, identity);
          continue;
        }
        // A gap carries THIS device's envelope for an older version — the one
        // place a retired key is handed back. `GET .../e2ee-key` never returns
        // it, so caching it here is what makes messages from before a rotation
        // readable offline afterwards.
        await _cacheEnvelope(conversationId, version, envelope);
        for (final userId in (gap['user_ids'] as List? ?? const [])) {
          final id = userId.toString();
          final result = await _repo.getE2eePublicKey(id);
          final publicJwk = Map<String, dynamic>.from(
            result['public_key'] as Map,
          );
          envelopes.add({
            'user_id': id,
            'key_version': version,
            'envelope': await _wrapKey(key, id, publicJwk),
          });
        }
      }
      if (envelopes.isEmpty) return false;
      final saved = await _repo.backfillE2eeConversationKey(
        conversationId,
        envelopes,
      );
      return ((saved['inserted'] as num?)?.toInt() ?? 0) > 0;
    } catch (_) {
      // A member who never set up secure messages, an offline moment, a key the
      // server would not hand out. Clearing the mark lets the next load retry.
      _backfilled.remove(conversationId);
      return false;
    }
  }
}

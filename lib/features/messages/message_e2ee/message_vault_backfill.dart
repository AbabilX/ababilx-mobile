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
  /// when at least one envelope landed. [newest] is the newest key version
  /// this account holds there.
  ///
  /// Best-effort by design: this runs beside a key load, so a failure must
  /// degrade to "their history stays sealed", never to a broken conversation.
  ///
  /// The server names who lost a key, and an old key opens history. So the
  /// phone decides for itself who gets one: in a DM only the peer, in a group
  /// only a member it knew before that key ([_knewMember]), and nobody whose
  /// identity changed until the user has looked ([isUnverifiedKeyChange]).
  Future<bool> _backfillKeys(
    String conversationId,
    String self,
    List<dynamic> gaps,
    int newest,
  ) async {
    if (gaps.isEmpty || _backfilled.contains(conversationId)) return false;
    _backfilled.add(conversationId);
    final identity = _identity;
    var waiting = false;
    try {
      final only = await _dmRoster(conversationId, self);
      if (only == null && !await _rosterKnown(conversationId, self)) {
        return false;
      }
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
          // An old key goes only to the people this DM is between.
          if (only != null && !only.contains(id)) continue;
          if (only == null &&
              !await _knewMember(conversationId, self, id, version, newest)) {
            continue;
          }
          final result = await _repo.getE2eePublicKey(id);
          final publicJwk = Map<String, dynamic>.from(
            result['public_key'] as Map,
          );
          onSealingTo?.call(self, id, publicJwk);
          // A different identity than the one remembered gets no history
          // until the user has confirmed it is the same person.
          if (await isUnverifiedKeyChange(self, id, publicJwk)) {
            waiting = true;
            continue;
          }
          envelopes.add({
            'user_id': id,
            'key_version': version,
            'envelope': await _wrapKey(key, id, publicJwk),
          });
        }
      }
      // Somebody is waiting on the user: the next load asks again.
      if (waiting) _backfilled.remove(conversationId);
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

  /// Makes sure this phone has a roster record for a group before any old
  /// key leaves it; the first roster it sees is taken as it is. False for a
  /// vault with no key cache (the notification isolate), which keeps no
  /// record and so hands no old group key: the app does, when it next runs.
  Future<bool> _rosterKnown(String conversationId, String self) async {
    if (_keyCache == null) return false;
    const pins = GroupRosterPins();
    if (await pins.known(self, conversationId)) return true;
    final roster = await _repo.getE2eeConversationMembers(conversationId);
    await pins.observe(self, conversationId, [
      for (final m in (roster['members'] as List? ?? const []))
        if (m is Map) '${m['user_id']}',
      for (final id in (roster['unready_member_ids'] as List? ?? const []))
        '$id',
    ]);
    return true;
  }

  /// Whether this phone knew [memberId] as a member before key [version]
  /// existed (GroupRosterPins): a new member is not handed the archive.
  Future<bool> _knewMember(
    String conversationId,
    String self,
    String memberId,
    int version,
    int newest,
  ) => const GroupRosterPins().mayHandKey(
    self,
    conversationId,
    memberId,
    version: version,
    newest: newest,
  );

  /// Records who a key was just sealed to, [before] being the newest version
  /// older than it. Never fails a send.
  Future<void> _noteRoster(
    String conversationId,
    String self,
    Iterable<String> memberIds,
    int before,
  ) async {
    if (_keyCache == null) return;
    try {
      await const GroupRosterPins().observe(
        self,
        conversationId,
        memberIds,
        before: before,
      );
    } catch (_) {}
  }

  /// Who a DM's keys may be sealed to, or null for a group and for a DM this
  /// phone has not listed yet. A vault built by hand (no key cache) runs in
  /// another isolate and re-reads what the app wrote.
  Future<Set<String>?> _dmRoster(String conversationId, String self) =>
      const DmRosterPins().roster(
        self,
        conversationId,
        reload: _keyCache == null,
      );
}

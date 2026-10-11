part of 'message_vault.dart';

/// The two repairs that make lost history come back without anyone opening the
/// conversation it was lost in.
extension MessageVaultRepair on MessageVault {
  /// Reports an envelope the server handed this device that would not open.
  ///
  /// The server checks an envelope's shape, never that it opens, so one can be
  /// sealed to an identity its owner no longer holds — a member who read our
  /// public key a moment before we started fresh seals the next version to the
  /// old one. Nothing else ever notices: the row exists, so the version is never
  /// rotated, and backfill will not overwrite it. Reporting drops the row, which
  /// makes the version stale (the next send rotates) and a gap (a member who
  /// still holds the key re-wraps it for us). The server refuses unless the
  /// public key sent is still this account's published identity, so a device
  /// holding a replaced identity cannot delete envelopes that are fine.
  ///
  /// [identity] is the identity the unwrap was attempted with. If it is no
  /// longer the one this vault holds, the failure says nothing about the row.
  Future<void> _reportUnreadableEnvelope(
    String conversationId,
    int version,
    P256KeyPair? identity,
  ) async {
    final publicJwk = _publicJwk;
    if (identity == null || !identical(identity, _identity)) return;
    if (publicJwk == null) return;
    final id = '$conversationId:$version';
    if (!_reportedUnreadable.add(id)) return;
    try {
      await _repo.reportUnreadableE2eeEnvelope(
        conversationId,
        version,
        publicJwk,
      );
      await _keyCache?.remove(conversationId, version);
    } catch (_) {
      // Offline, or an older server. One attempt per session is the cap only
      // when it got through.
      _reportedUnreadable.remove(id);
    }
  }

  /// Hands every key version this account holds to members who lost theirs,
  /// across all conversations. Once per unlocked identity.
  ///
  /// Backfill used to run only when this device happened to load a
  /// conversation's key over the network — and reading from the stored
  /// envelope never does — so after somebody started fresh their history came
  /// back only in the chats we happened to write in. The server names the
  /// conversations with a gap this account can fill; loading each key runs the
  /// ordinary backfill.
  Future<void> fillKeyGaps(String currentUserId) {
    if (!isUnlocked || currentUserId.isEmpty) return Future.value();
    return _gapFill ??= _runGapFill(currentUserId);
  }

  /// Runs the pass again now: the user has confirmed a member's new
  /// identity, and the last pass held their old keys back for that.
  Future<void> refillKeyGaps(String currentUserId) {
    _backfilled.clear();
    _gapFill = null;
    return fillKeyGaps(currentUserId);
  }

  Future<void> _runGapFill(String self) async {
    final identity = _identity;
    try {
      final result = await _repo.getE2eeFillableGaps();
      for (final id in (result['conversation_ids'] as List? ?? const [])) {
        if (!identical(identity, _identity)) return;
        try {
          await _loadKey(id.toString(), self, refresh: true);
        } catch (_) {
          // One conversation that will not load must not stop the rest.
        }
      }
    } catch (_) {
      // Unreachable server: let the next launch or unlock try again.
      if (identical(identity, _identity)) _gapFill = null;
    }
  }
}

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'safety_number.dart';
import 'safety_number_store.dart';

String _fingerprintOf(Map<String, dynamic> args) => identityFingerprint(
  SafetyIdentity(
    userId: args['id'] as String,
    publicKey: Map<String, dynamic>.from(args['key'] as Map),
  ),
);

/// Remembers the identity key of everyone this phone seals a conversation key
/// to, and notices when the server hands out a different one.
///
/// The server is the only source of another member's public key, so it could
/// hand out its own and be sealed a copy of the conversation key. Comparing
/// safety numbers catches that, and nobody compares them unprompted. This is
/// the prompt: the first key seen for a person is remembered (trust on first
/// use), and a later different one is reported in every chat with them until
/// the user has looked. A person who started fresh looks exactly the same from
/// here, which is why it warns and does not block. Signal's rule.
class MemberKeyWatch {
  MemberKeyWatch(this._store);

  final SafetyNumberStore _store;

  // Hashing only, keyed on the key material itself: 5200 SHA-512 rounds per
  // member is too much to repeat each time a group opens.
  static final _memo = <String, Future<String>>{};

  Future<String> fingerprint(String userId, Map<String, dynamic> publicKey) {
    final id = '$userId|${publicKey['x']}|${publicKey['y']}';
    return _memo[id] ??= compute(_fingerprintOf, <String, dynamic>{
      'id': userId,
      'key': publicKey,
    });
  }

  /// Compares [publicKey] with what this phone remembers for [peerUserId].
  /// Pass [sealing] when a key is about to be sealed to it: a change is then
  /// flagged, so it stays reported whatever the server answers later.
  Future<PeerTrust> observe(
    String ownerUserId,
    String peerUserId,
    Map<String, dynamic> publicKey, {
    bool sealing = false,
  }) async {
    if (ownerUserId.isEmpty || peerUserId.isEmpty) return PeerTrust.firstSeen;
    if (ownerUserId == peerUserId) return PeerTrust.unchanged;
    final String print;
    try {
      print = await fingerprint(peerUserId, publicKey);
    } catch (_) {
      // A key that cannot be hashed cannot be sealed to either.
      return PeerTrust.firstSeen;
    }
    final trust = await _store.check(ownerUserId, peerUserId, print);
    if (trust == PeerTrust.firstSeen) {
      await _store.remember(ownerUserId, peerUserId, print);
    } else if (trust == PeerTrust.changed && sealing) {
      await _store.flag(ownerUserId, peerUserId);
    }
    if (trust == PeerTrust.unchanged &&
        await _store.isFlagged(ownerUserId, peerUserId)) {
      return PeerTrust.changed;
    }
    return trust;
  }
}

final memberKeyWatchProvider = Provider<MemberKeyWatch>(
  (ref) => MemberKeyWatch(ref.watch(safetyNumberStoreProvider)),
);

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/chat_repository.dart';
import '../message_e2ee/message_vault.dart';
import '../providers/chat_provider.dart';
import 'safety_number.dart';
import 'safety_number_store.dart';

/// What this device can say about a DM's safety number right now.
class SafetyNumberInfo {
  const SafetyNumberInfo({
    required this.digits,
    required this.peerFingerprint,
    required this.trust,
  });

  final String digits;
  final String peerFingerprint;
  final PeerTrust trust;

  bool get changed => trust == PeerTrust.changed;
}

/// Runs off the UI isolate. 5200 SHA-512 rounds cost about 10 ms on a laptop
/// and several times that on a cheap phone, twice per conversation — enough to
/// drop frames if it ran where the list is scrolling.
Map<String, String> _derive(Map<String, dynamic> args) {
  final mine = SafetyIdentity(
    userId: args['my_id'] as String,
    publicKey: Map<String, dynamic>.from(args['my_key'] as Map),
  );
  final theirs = SafetyIdentity(
    userId: args['peer_id'] as String,
    publicKey: Map<String, dynamic>.from(args['peer_key'] as Map),
  );
  return {
    'digits': safetyNumber(mine, theirs),
    'peer': identityFingerprint(theirs),
  };
}

/// The safety number for one DM peer, plus whether their key changed since this
/// device last looked.
///
/// The peer's key is fetched from the server every time rather than read from a
/// cache: a stale copy would hide exactly the substitution this exists to catch.
/// Returns null when there is nothing meaningful to say — no identity on this
/// device yet, or the peer has not set up secure messages.
final safetyNumberProvider = FutureProvider.autoDispose
    .family<SafetyNumberInfo?, String>((ref, peerUserId) async {
      final myId = ref.watch(chatProvider.select((s) => s.currentUserId));
      final myKey = ref.read(messageVaultProvider).publicIdentity;
      if (myId.isEmpty || peerUserId.isEmpty || myKey == null) return null;

      final Map<String, dynamic> response;
      try {
        response = await ref
            .read(chatRepositoryProvider)
            .getE2eePublicKey(peerUserId);
      } catch (_) {
        // 404 here means the peer has no identity yet, which is a normal state
        // and not something to shout about.
        return null;
      }
      final peerKey = response['public_key'];
      if (peerKey is! Map) return null;

      final Map<String, String> derived;
      try {
        derived = await compute(_derive, <String, dynamic>{
          'my_id': myId,
          'my_key': myKey,
          'peer_id': peerUserId,
          'peer_key': Map<String, dynamic>.from(peerKey),
        });
      } catch (_) {
        return null;
      }

      final peerFingerprint = derived['peer']!;
      return SafetyNumberInfo(
        digits: derived['digits']!,
        peerFingerprint: peerFingerprint,
        trust: await ref
            .read(safetyNumberStoreProvider)
            .check(myId, peerUserId, peerFingerprint),
      );
    });

/// Records the peer's current key as the expected one and re-reads the check,
/// so the warning clears the moment the user says they compared the digits.
Future<void> acknowledgeSafetyNumber(
  WidgetRef ref,
  String peerUserId,
  String peerFingerprint,
) async {
  final myId = ref.read(chatProvider).currentUserId;
  if (myId.isEmpty) return;
  await ref
      .read(safetyNumberStoreProvider)
      .remember(myId, peerUserId, peerFingerprint);
  ref.invalidate(safetyNumberProvider(peerUserId));
}

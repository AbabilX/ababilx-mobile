import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/chat_repository.dart';
import '../message_e2ee/group_roster_pins.dart';
import '../providers/chat_provider.dart';
import 'member_key_watch.dart';
import 'safety_number_provider.dart';
import 'safety_number_store.dart';

/// The vault's hook: a conversation key is about to be sealed to [userId]'s
/// [publicJwk]. Never awaited by the send. A change redraws the warnings.
void watchSealedKey(
  Ref ref,
  String self,
  String userId,
  Map<String, dynamic> publicJwk,
) {
  unawaited(
    ref
        .read(memberKeyWatchProvider)
        .observe(self, userId, publicJwk, sealing: true)
        .then((trust) {
          if (trust != PeerTrust.changed) return;
          ref.invalidate(safetyNumberProvider(userId));
          ref.invalidate(memberKeyChangesProvider);
        })
        .catchError((_) {}),
  );
}

/// Whether [publicJwk] is a different identity than the one this phone
/// remembers for [userId], and the user has not confirmed it yet.
///
/// Asked by the vault before it hands an OLD conversation key to someone who
/// lost theirs. A person who started fresh looks exactly like a key the
/// server swapped, and an old key opens the whole history: so it waits for
/// the user (the safety-number screen), where a new message only warns.
/// Storage that cannot be read holds nothing back; the server cannot cause it.
Future<bool> isUnverifiedKeyChange(
  String self,
  String userId,
  Map<String, dynamic> publicJwk,
) async {
  try {
    const store = SafetyNumberStore();
    final trust = await MemberKeyWatch(
      store,
    ).observe(self, userId, publicJwk, sealing: true);
    return trust == PeerTrust.changed;
  } catch (_) {
    return false;
  }
}

/// The members of a group whose identity key is not the one this phone
/// remembers, by user id. Empty for almost every group, almost always.
///
/// Reads the same roster a key is sealed to (`e2ee-members`), so a group is
/// checked when it is opened and not only when this phone happens to re-key
/// it. First sight of a member is remembered here too.
final memberKeyChangesProvider = FutureProvider.autoDispose
    .family<List<String>, String>((ref, conversationId) async {
      final myId = ref.watch(chatProvider.select((s) => s.currentUserId));
      if (myId.isEmpty || conversationId.isEmpty) return const [];
      final Map<String, dynamic> roster;
      try {
        roster = await ref
            .read(chatRepositoryProvider)
            .getE2eeConversationMembers(conversationId);
      } catch (_) {
        return const [];
      }
      // The same roster is this phone's record of who reads the group: a
      // member who appeared since the last look is listed (GroupRosterNotice).
      await const GroupRosterPins().observe(myId, conversationId, [
        for (final entry in (roster['members'] as List? ?? const []))
          if (entry is Map) '${entry['user_id']}',
        for (final id in (roster['unready_member_ids'] as List? ?? const []))
          '$id',
      ]);
      final watch = ref.read(memberKeyWatchProvider);
      final changed = <String>[];
      for (final entry in (roster['members'] as List? ?? const [])) {
        if (entry is! Map) continue;
        final userId = entry['user_id']?.toString() ?? '';
        final key = entry['public_key'];
        if (userId.isEmpty || userId == myId || key is! Map) continue;
        final trust = await watch.observe(
          myId,
          userId,
          Map<String, dynamic>.from(key),
        );
        if (trust == PeerTrust.changed) changed.add(userId);
      }
      return changed;
    });

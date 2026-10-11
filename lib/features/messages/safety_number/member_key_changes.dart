import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/chat_repository.dart';
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

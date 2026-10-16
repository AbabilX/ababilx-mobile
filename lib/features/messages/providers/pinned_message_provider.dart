import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/first_load_timeout.dart';
import '../chat-pins/pin_local_copy.dart';
import '../data/chat_repository.dart';
import '../data/local/chat_message_store.dart';
import '../data/models/chat_models.dart';
import 'chat_provider.dart';

/// The caller's own pins in one chat, newest first, opened on this device.
/// The server lists only messages still visible to them, so a deleted or
/// hidden message drops out on the next read. A pinned message the server
/// already let go to the phones (0173) comes back empty and is drawn from
/// this phone's copy.
final pinnedMessagesProvider = FutureProvider.autoDispose
    .family<List<ChatPinnedMessage>, String>((ref, conversationId) async {
      final pins = await ref
          .watch(chatRepositoryProvider)
          .pinnedMessages(conversationId)
          .timeout(firstLoadNetworkTimeout);
      final local = await pinnedWithLocalCopies(
        ref.read(chatMessageStoreProvider),
        [for (final pin in pins) pin.message],
      );
      final kept = [
        for (var i = 0; i < pins.length; i++)
          if (local[i] != null) pins[i].withMessage(local[i]!),
      ];
      final opened = await ref.read(chatProvider.notifier).decryptIfNeeded([
        for (final pin in kept) pin.message,
      ]);
      return [
        for (var i = 0; i < kept.length; i++) kept[i].withMessage(opened[i]),
      ];
    });

/// Which messages are pinned, for the long-press menu's Pin / Unpin label.
final pinnedMessageIdsProvider = Provider.autoDispose
    .family<Set<String>, String>(
      (ref, conversationId) => {
        for (final pin
            in ref.watch(pinnedMessagesProvider(conversationId)).valueOrNull ??
                const <ChatPinnedMessage>[])
          pin.message.id,
      },
    );

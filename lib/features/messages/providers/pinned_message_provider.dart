import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/first_load_timeout.dart';
import '../data/chat_repository.dart';
import '../data/models/chat_models.dart';
import 'chat_provider.dart';

/// The caller's own pins in one chat, newest first, opened on this device.
/// The server lists only messages still visible to them, so a deleted or
/// hidden message drops out on the next read.
final pinnedMessagesProvider = FutureProvider.autoDispose
    .family<List<ChatPinnedMessage>, String>((ref, conversationId) async {
      final pins = await ref
          .watch(chatRepositoryProvider)
          .pinnedMessages(conversationId)
          .timeout(firstLoadNetworkTimeout);
      final opened = await ref.read(chatProvider.notifier).decryptIfNeeded([
        for (final pin in pins) pin.message,
      ]);
      return [
        for (var i = 0; i < pins.length; i++) pins[i].withMessage(opened[i]),
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

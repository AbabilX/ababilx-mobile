import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/first_load_timeout.dart';
import '../chat-pins/pin_local_copy.dart';
import '../data/local/chat_message_store.dart';
import '../group-member-permissions/group_admin_api.dart';
import '../providers/chat_provider.dart';

/// A group's shared pins (server 0157), newest first, opened on this device.
/// Refetched on `chat.group_pins.updated`. The server filters by what this
/// viewer may see, so a member who joined later never gets a pin on a message
/// sealed before they arrived.
final groupPinsProvider = FutureProvider.autoDispose
    .family<GroupPinsPage, String>((ref, conversationId) async {
      final page = await listGroupPins(
        ref.watch(apiClientProvider),
        conversationId,
      ).timeout(firstLoadNetworkTimeout);
      final local = await pinnedWithLocalCopies(
        ref.read(chatMessageStoreProvider),
        [for (final pin in page.pins) pin.message],
      );
      final kept = [
        for (var i = 0; i < page.pins.length; i++)
          if (local[i] != null) page.pins[i].withMessage(local[i]!),
      ];
      final opened = await ref.read(chatProvider.notifier).decryptIfNeeded([
        for (final pin in kept) pin.message,
      ]);
      return GroupPinsPage(
        pins: [
          for (var i = 0; i < kept.length; i++) kept[i].withMessage(opened[i]),
        ],
        canPin: page.canPin,
      );
    });

/// Which messages are pinned for everyone, for the long-press menu.
final groupPinnedIdsProvider = Provider.autoDispose.family<Set<String>, String>(
  (ref, conversationId) => {
    for (final pin
        in ref.watch(groupPinsProvider(conversationId)).valueOrNull?.pins ??
            const <GroupPin>[])
      pin.message.id,
  },
);

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/local/chat_message_row.dart';
import '../data/models/chat_models.dart';
import '../group-member-permissions/group_admin_api.dart';
import '../group-pins/group_pins_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/pinned_message_provider.dart';

/// One message on the Pins page. A group message can be pinned for the
/// caller, for everyone, or both — it is still one row.
class ChatPinEntry {
  const ChatPinEntry({
    required this.message,
    required this.mine,
    required this.everyone,
  });

  final ChatMessage message;
  final bool mine;
  final bool everyone;
}

/// What the Pins page draws: the caller's own pins plus, in a group, the
/// group's shared pins (server 0157). Both used to be separate surfaces — the
/// shared ones a bar over the timeline — and a group now works like a DM:
/// one page, reached from chat details.
class ChatPinsView {
  const ChatPinsView({this.entries = const [], this.canPinGroup = false});

  final List<ChatPinEntry> entries;

  /// Whether the caller may unpin the group's shared pins.
  final bool canPinGroup;

  bool canUnpin(ChatPinEntry entry) =>
      entry.mine || (entry.everyone && canPinGroup);
}

bool _isGroup(Ref ref, String conversationId) => ref.watch(
  chatProvider.select(
    (c) => c.conversationById(conversationId)?.type == 'group',
  ),
);

/// Both pin lists merged, loading until the caller's own list is in. A group
/// list that fails leaves the caller's own pins showing rather than blanking
/// the page.
final chatPinsProvider = Provider.autoDispose
    .family<AsyncValue<ChatPinsView>, String>((ref, conversationId) {
      final own = ref.watch(pinnedMessagesProvider(conversationId));
      final group = _isGroup(ref, conversationId)
          ? ref.watch(groupPinsProvider(conversationId))
          : const AsyncValue<GroupPinsPage>.data(GroupPinsPage());
      if (!own.hasValue) {
        if (own.hasError) {
          return AsyncValue.error(own.error!, own.stackTrace!);
        }
        return const AsyncValue.loading();
      }
      if (group.isLoading && !group.hasValue) return const AsyncValue.loading();
      final byId = <String, ChatPinEntry>{};
      for (final pin in group.valueOrNull?.pins ?? const <GroupPin>[]) {
        byId[pin.message.id] = ChatPinEntry(
          message: pin.message,
          mine: false,
          everyone: true,
        );
      }
      for (final pin in own.value!) {
        final shared = byId[pin.message.id];
        byId[pin.message.id] = ChatPinEntry(
          message: shared?.message ?? pin.message,
          mine: true,
          everyone: shared != null,
        );
      }
      final entries = byId.values.toList()
        ..sort(
          (a, b) =>
              messageTimeMs(b.message).compareTo(messageTimeMs(a.message)),
        );
      return AsyncValue.data(
        ChatPinsView(
          entries: entries,
          canPinGroup: group.valueOrNull?.canPin ?? false,
        ),
      );
    });

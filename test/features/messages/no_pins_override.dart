import 'package:ababilx/features/messages/data/models/chat_models.dart';
import 'package:ababilx/features/messages/group-member-permissions/group_admin_api.dart';
import 'package:ababilx/features/messages/group-pins/group_pins_provider.dart';
import 'package:ababilx/features/messages/providers/pinned_message_provider.dart';

/// The chat and its details screen read the caller's pins from the server.
/// Widget tests that are not about pins answer "none" instead of opening a
/// request that outlives the test.
final noPinsOverride = pinnedMessagesProvider.overrideWith(
  (ref, conversationId) async => const <ChatPinnedMessage>[],
);

/// Same for a group's shared pins, which the Pins page and the long-press
/// menu read beside the caller's own.
final noGroupPinsOverride = groupPinsProvider.overrideWith(
  (ref, conversationId) async => const GroupPinsPage(),
);

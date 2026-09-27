import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/chat_provider.dart';
import '../wallpaper/chat_wallpaper_provider.dart';
import 'chat_pin_unpin.dart';
import 'chat_pins_provider.dart';
import 'pinned_message_item.dart';

/// The Pins page's bubbles, newest at the bottom like the chat itself:
/// [entries] is what the search left of [view] (the whole view when none).
class PinnedMessagesList extends ConsumerWidget {
  const PinnedMessagesList({
    super.key,
    required this.conversationId,
    required this.entries,
    required this.view,
    required this.fab,
  });

  final String conversationId;
  final List<ChatPinEntry> entries;
  final ChatPinsView view;

  /// Unpin all is floating over the bottom, so the newest pin keeps clear.
  final bool fab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = conversationId;
    final userId = ref.watch(chatProvider.select((c) => c.currentUserId));
    final isGroup = ref.watch(
      chatProvider.select(
        (c) => c.conversationById(id)?.isGroupConversation ?? false,
      ),
    );
    final hasWallpaper = ref.watch(chatWallpaperProvider).forChat(id).isSet;
    final insets = MediaQuery.viewPaddingOf(context);
    // Newest at the bottom, like the chat itself: a reversed list opens there.
    return ListView.builder(
      reverse: true,
      padding: EdgeInsets.only(
        top: insets.top + 84,
        // Room for the Unpin all pill, so the newest pin is not under it.
        bottom: insets.bottom + (fab ? 88 : 16),
      ),
      itemCount: entries.length,
      itemBuilder: (context, i) {
        final entry = entries[i];
        final message = entry.message;
        return PinnedMessageItem(
          key: ValueKey(message.id),
          message: message,
          isOwn: message.userId == userId,
          isGroup: isGroup,
          hasWallpaper: hasWallpaper,
          pinnedForEveryone: isGroup && entry.everyone,
          onOpen: () => context.pop(message.id),
          onUnpin: view.canUnpin(entry)
              ? () => unpinChatPin(
                  context,
                  ref,
                  id,
                  entry,
                  canPinGroup: view.canPinGroup,
                )
              : null,
        );
      },
    );
  }
}

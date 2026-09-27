import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_translations.dart';
import '../group-pins/group_pins_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/pinned_message_provider.dart';
import '../wallpaper/chat_wallpaper_background.dart';
import '../wallpaper/chat_wallpaper_provider.dart';
import 'chat_pin_unpin.dart';
import 'chat_pins_provider.dart';
import 'pinned_message_item.dart';
import 'pinned_messages_chrome.dart';
import 'pinned_messages_notice.dart';
import 'unpin_all_sheet.dart';

/// Every message the caller pinned in one chat, drawn the way Telegram's
/// "N Pinned Messages" does: the chat's wallpaper, the real bubbles in chat
/// order with the newest at the bottom, a go-to arrow beside each, and
/// "Unpin all" in the header (asks first). Choosing one answers its id to
/// whoever opened this screen, which walks the chat to it. A group lists its
/// shared pins here too, marked "Pinned for everyone" — there is no pin bar
/// over the timeline, in a group or a DM.
class PinnedMessagesScreen extends ConsumerStatefulWidget {
  const PinnedMessagesScreen({super.key, required this.conversationId});

  final String conversationId;

  @override
  ConsumerState<PinnedMessagesScreen> createState() =>
      _PinnedMessagesScreenState();
}

class _PinnedMessagesScreenState extends ConsumerState<PinnedMessagesScreen> {
  bool _unpinningAll = false;

  String _tr(String key) => AppTranslations.translate(context, ref, key);

  @override
  Widget build(BuildContext context) {
    final id = widget.conversationId;
    final pins = ref.watch(chatPinsProvider(id));
    final view = pins.valueOrNull ?? const ChatPinsView();
    final unpinnable = view.entries.where(view.canUnpin).length;
    final title = switch (view.entries.length) {
      0 => _tr('chat_pinned_messages'),
      1 => _tr('chat_pins_title_one'),
      final n => _tr('chat_pins_title').replaceAll('{count}', '$n'),
    };
    return Scaffold(
      body: ChatWallpaperBackground(
        conversationId: id,
        child: Stack(
          children: [
            Positioned.fill(child: _body(pins, view)),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: PinnedMessagesTopBar(
                title: title,
                trailing: unpinnable == 0
                    ? null
                    : PinnedMessagesUnpinAllButton(
                        label: _tr('chat_unpin_all_short'),
                        onPressed: _unpinningAll
                            ? null
                            : () => _unpinAll(view, unpinnable),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body(AsyncValue<ChatPinsView> pins, ChatPinsView view) {
    final id = widget.conversationId;
    if (pins.isLoading && !pins.hasValue) {
      return const Center(child: CircularProgressIndicator());
    }
    if (pins.hasError && !pins.hasValue) {
      return PinnedMessagesNotice(
        title: _tr('chat_pins_load_failed'),
        action: TextButton(
          onPressed: () => ref
            ..invalidate(pinnedMessagesProvider(id))
            ..invalidate(groupPinsProvider(id)),
          child: Text(_tr('recovery_retry')),
        ),
      );
    }
    if (view.entries.isEmpty) {
      return PinnedMessagesNotice(
        title: _tr('chat_pins_empty_title'),
        body: _tr('chat_pins_empty_body'),
      );
    }
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
        bottom: insets.bottom + 16,
      ),
      itemCount: view.entries.length,
      itemBuilder: (context, i) {
        final entry = view.entries[i];
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

  Future<void> _unpinAll(ChatPinsView view, int count) async {
    final confirmed = await confirmUnpinAll(context, ref, count);
    if (!confirmed || !mounted) return;
    setState(() => _unpinningAll = true);
    final ok = await unpinAllChatPins(
      context,
      ref,
      widget.conversationId,
      view,
    );
    if (!mounted) return;
    setState(() => _unpinningAll = false);
    // A member's own pins can go while the group's stay; close only on empty.
    if (ok && count == view.entries.length) context.pop();
  }
}

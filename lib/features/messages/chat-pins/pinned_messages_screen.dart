import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_translations.dart';
import '../chat-timeline/pinned_message_actions.dart';
import '../data/local/chat_message_row.dart';
import '../data/models/chat_models.dart';
import '../providers/chat_provider.dart';
import '../providers/pinned_message_provider.dart';
import '../wallpaper/chat_wallpaper_background.dart';
import '../wallpaper/chat_wallpaper_provider.dart';
import 'pinned_message_item.dart';
import 'pinned_messages_chrome.dart';

/// Every message the caller pinned in one chat, drawn the way Telegram's
/// "N Pinned Messages" does: the chat's wallpaper, the real bubbles in chat
/// order with the newest at the bottom, a go-to arrow beside each, and
/// "Unpin all messages" underneath. Choosing one answers its id to whoever
/// opened this screen, which walks the chat to it.
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
    final pins = ref.watch(pinnedMessagesProvider(id));
    final messages = [...?pins.value?.map((pin) => pin.message)]
      ..sort((a, b) => messageTimeMs(b).compareTo(messageTimeMs(a)));
    final title = switch (messages.length) {
      0 => _tr('chat_pinned_messages'),
      1 => _tr('chat_pins_title_one'),
      final n => _tr('chat_pins_title').replaceAll('{count}', '$n'),
    };
    return Scaffold(
      body: ChatWallpaperBackground(
        conversationId: id,
        child: Stack(
          children: [
            Positioned.fill(child: _body(pins, messages)),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: PinnedMessagesTopBar(title: title),
            ),
            if (messages.isNotEmpty)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: PinnedMessagesUnpinAllBar(
                  label: _tr('chat_unpin_all'),
                  onPressed: _unpinningAll
                      ? null
                      : () => _unpinAll(messages.map((m) => m.id).toList()),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _body(AsyncValue<Object?> pins, List<ChatMessage> messages) {
    final id = widget.conversationId;
    if (pins.isLoading && !pins.hasValue) {
      return const Center(child: CircularProgressIndicator());
    }
    if (pins.hasError && !pins.hasValue) {
      return PinnedMessagesNotice(
        title: _tr('chat_pins_load_failed'),
        action: TextButton(
          onPressed: () => ref.invalidate(pinnedMessagesProvider(id)),
          child: Text(_tr('recovery_retry')),
        ),
      );
    }
    if (messages.isEmpty) {
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
        bottom: insets.bottom + 84,
      ),
      itemCount: messages.length,
      itemBuilder: (context, i) {
        final message = messages[i];
        return PinnedMessageItem(
          key: ValueKey(message.id),
          message: message,
          isOwn: message.userId == userId,
          isGroup: isGroup,
          hasWallpaper: hasWallpaper,
          onOpen: () => context.pop(message.id),
          onUnpin: () =>
              setMessagePinned(context, ref, id, message.id, pinned: false),
        );
      },
    );
  }

  Future<void> _unpinAll(List<String> ids) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(
          _tr('chat_unpin_all_confirm').replaceAll('{count}', '${ids.length}'),
        ),
        content: Text(_tr('chat_unpin_all_body')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(false),
            child: Text(_tr('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(true),
            child: Text(_tr('chat_unpin_all')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _unpinningAll = true);
    final ok = await unpinAllMessages(context, ref, widget.conversationId, ids);
    if (!mounted) return;
    setState(() => _unpinningAll = false);
    if (ok) context.pop();
  }
}
